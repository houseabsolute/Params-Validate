/* Copyright (c) 2000-2003 Dave Rolsky
   All rights reserved.
   This program is free software; you can redistribute it and/or
   modify it under the same terms as Perl itself.  See the LICENSE
   file that comes with this distribution for more details. */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_newCONSTSUB
#include "ppport.h"

/* not defined in 5.00503 _or_ ppport.h! */
#ifndef CopSTASHPV
#  ifdef USE_ITHREADS
#    define CopSTASHPV(c)         ((c)->cop_stashpv)
#  else
#    define CopSTASH(c)           ((c)->cop_stash)
#    define CopSTASHPV(c)         (CopSTASH(c) ? HvNAME(CopSTASH(c)) : Nullch)
#  endif /* USE_ITHREADS */
#endif /* CopSTASHPV */

#ifndef PERL_MAGIC_qr
#  define PERL_MAGIC_qr          'r'
#endif /* PERL_MAGIC_qr */

/* type constants */
#define SCALAR    1
#define ARRAYREF  2
#define HASHREF   4
#define CODEREF   8
#define GLOB      16
#define GLOBREF   32
#define SCALARREF 64
#define UNKNOWN   128
#define UNDEF     256
#define OBJECT    512

#define HANDLE    (GLOB | GLOBREF)
#define BOOLEAN   (SCALAR | UNDEF)

/* return data macros */
#define RETURN_ARRAY(ret) \
    STMT_START {                                      \
        switch(GIMME_V) {                             \
        case G_VOID:                                  \
            return;                                   \
        case G_ARRAY:                                 \
            EXTEND(SP, av_len(ret) + 1);              \
            for(i = 0; i <= av_len(ret); i ++) {      \
                PUSHs(*av_fetch(ret, i, 1));          \
            }                                         \
            break;                                    \
        case G_SCALAR:                                \
            XPUSHs(sv_2mortal(newRV_inc((SV*) ret))); \
            break;                                    \
        }                                             \
    } STMT_END


#define RETURN_HASH(ret) \
    STMT_START {                                      \
        HE* he;                                       \
        I32 keys;                                     \
        switch(GIMME_V) {                             \
        case G_VOID:                                  \
            return;                                   \
        case G_ARRAY:                                 \
            keys = hv_iterinit(ret);                  \
            EXTEND(SP, keys * 2);                     \
            while(he = hv_iternext(ret)) {            \
                PUSHs(HeSVKEY_force(he));             \
                PUSHs(HeVAL(he));                     \
            }                                         \
            break;                                    \
        case G_SCALAR:                                \
            XPUSHs(sv_2mortal(newRV_inc((SV*) ret))); \
            break;                                    \
        }                                             \
    } STMT_END

/* enable/disable validation */
static int NO_VALIDATE ;

/* module initialization */
static void
bootinit()
{
    char *str;
    HV* stash;

    /* turn on/off validation */
    str = PerlEnv_getenv("PERL_NO_VALIDATION");
    if(str) {
        NO_VALIDATE = SvIV(sv_2mortal(newSVpv(str, 0)));
    } else {
        NO_VALIDATE = 0;
    }

    /* define constants */
    stash = gv_stashpv("Params::Validate", 1);
    newCONSTSUB(stash, "SCALAR", newSViv(SCALAR));
    newCONSTSUB(stash, "ARRAYREF", newSViv(ARRAYREF));
    newCONSTSUB(stash, "HASHREF", newSViv(HASHREF));
    newCONSTSUB(stash, "CODEREF", newSViv(CODEREF));
    newCONSTSUB(stash, "GLOB", newSViv(GLOB));
    newCONSTSUB(stash, "GLOBREF", newSViv(GLOBREF));
    newCONSTSUB(stash, "SCALARREF", newSViv(SCALARREF));
    newCONSTSUB(stash, "UNKNOWN", newSViv(UNKNOWN));
    newCONSTSUB(stash, "UNDEF", newSViv(UNDEF));
    newCONSTSUB(stash, "OBJECT", newSViv(OBJECT));
    newCONSTSUB(stash, "HANDLE", newSViv(HANDLE));
    newCONSTSUB(stash, "BOOLEAN", newSViv(BOOLEAN));
}

/* return type string that corresponds to typemask */
static SV*
typemask_to_string(IV mask)
{
    SV* buffer;
    IV empty = 1;

    buffer = sv_2mortal(newSVpv("", 0));

    if(mask & SCALAR) {
        sv_catpv(buffer, "scalar");
        empty = 0;
    }
    if(mask & ARRAYREF) {
        sv_catpv(buffer, empty ? "arrayref" : " arrayref");
        empty = 0;
    }
    if(mask & HASHREF) {
        sv_catpv(buffer, empty ? "hashref" : " hashref");
        empty = 0;
    }
    if(mask & CODEREF) {
        sv_catpv(buffer, empty ? "coderef" : " coderef");
        empty = 0;
    }
    if(mask & GLOB) {
        sv_catpv(buffer, empty ? "glob" : " glob");
        empty = 0;
    }
    if(mask & GLOBREF) {
        sv_catpv(buffer, empty ? "globref" : " globref");
        empty = 0;
    }
    if(mask & SCALARREF) {
        sv_catpv(buffer, empty ? "scalarref" : " scalarref");
        empty = 0;
    }
    if(mask & UNDEF) {
        sv_catpv(buffer, empty ? "undef" : " undef");
        empty = 0;
    }
    if(mask & OBJECT) {
        sv_catpv(buffer, empty ? "object" : " object");
        empty = 0;
    }
    if(mask & UNKNOWN) {
        sv_catpv(buffer, empty ? "unknown" : " unknown");
        empty = 0;
    }

    return buffer;
}

/* compute numberic datatype for variable */
static IV
get_type(SV* sv)
{
    IV type = 0;

    if(SvTYPE(sv) == SVt_PVGV) return GLOB;
    if(!SvOK(sv)) return UNDEF;
    if(!SvROK(sv)) return SCALAR;

    switch(SvTYPE(SvRV(sv))) {
    case SVt_NULL:
    case SVt_IV:
    case SVt_NV:
    case SVt_PV:
    case SVt_RV:
    case SVt_PVMG:
    case SVt_PVIV:
    case SVt_PVNV:
    case SVt_PVBM:
        type = SCALARREF;
        break;
    case SVt_PVAV:
        type = ARRAYREF;
        break;
    case SVt_PVHV:
        type = HASHREF;
        break;
    case SVt_PVCV:
        type = CODEREF;
        break;
    case SVt_PVGV:
        type = GLOBREF;
        break;
    }

    if(type) {
        if(sv_isobject(sv)) return type | OBJECT;
        return type;
    }

    /* I really hope this never happens */
    return UNKNOWN;
}

/* get an article for given string */
#if (PERL_VERSION >= 6) /* Perl 5.6.0+ */
static const char*
#else
static char*
#endif
article(SV* string)
{
    STRLEN len;
    char* rawstr;

    rawstr = SvPV(string, len);
    if(len) {
        switch(rawstr[0]) {
        case 'a':
        case 'e':
        case 'i':
        case 'o':
        case 'u':
            return "an";
        }
    }

    return "a";
}

/* raises exception either using user-defined callback or using
   built-in method */
static void
validation_failure(SV* message, HV* options)
{
    SV** temp;
    SV* on_fail;
    I32 flags = PERL_VERSION >= 6 ? G_DISCARD | G_EVAL : G_DISCARD;

    if(temp = hv_fetch(options, "on_fail", 7, 0)) {
        SvGETMAGIC(*temp);
        on_fail = *temp;
    } else {
        on_fail = NULL;
    }

    /* use user defined callback if avialable */
    if(on_fail) {
        dSP;
        PUSHMARK(SP);
        XPUSHs(message);
        PUTBACK;
        perl_call_sv(on_fail, flags);
        /* for some reason, 5.00503 segfaults if we use the G_EVAL
           flag, get a ref in ERRSV, and then call Nullch.  5.6.1
           segfaults if we _don't_ use the G_EVAL flag */
#if (PERL_VERSION >= 6)
        if (SvTRUE(ERRSV)) {
            if (SvROK(ERRSV)) {
                croak(Nullch);
            } else {
                croak(SvPV_nolen(ERRSV));
            }
        } else {
            croak(SvPV_nolen(message));
        }
#endif
        return;
    }

    /* by default resort to Carp::confess for error reporting */
    {
        dSP;
        perl_require_pv("Carp.pm");
        PUSHMARK(SP);
        XPUSHs(message);
        PUTBACK;
        perl_call_pv("Carp::croak", flags);
#if (PERL_VERSION >= 6)
        if (SvTRUE(ERRSV)) {
            if (SvROK(ERRSV)) {
                croak(Nullch);
            } else {
                croak(SvPV_nolen(ERRSV));
            }
        } else {
            croak(SvPV_nolen(message));
        }
#endif
    }

    return;
}

/* get called subroutine fully qualified name */
static SV*
get_called(HV* options)
{
    SV** temp;

    if(temp = hv_fetch(options, "called", 6, 0)) {
        SvGETMAGIC(*temp);
        return *temp;
    } else {
        IV frame;
        SV* buffer;
        SV* caller;

        if(temp = hv_fetch(options, "stack_skip", 10, 0)) {
            SvGETMAGIC(*temp);
            frame = SvIV(*temp);
        } else {
            frame = 1;
        }

        buffer = sv_2mortal(newSVpvf("(caller(%d))[3]", (int) frame));

        caller = perl_eval_pv(SvPV_nolen(buffer), 1);
        if(SvTYPE(caller) == SVt_NULL) {
            sv_setpv(caller, "N/A");
        }

        return caller;
    }
}

/* UNIVERSAL::isa alike validation */
static void
validate_isa(SV* value, SV* package, SV* id, HV* options)
{
    SV* buffer;

    /* quick test directly from Perl internals */
    if(sv_derived_from(value, SvPV_nolen(package))) return;

    buffer = sv_2mortal(newSVsv(id));
    sv_catpv(buffer, " to ");
    sv_catsv(buffer, get_called(options));
    sv_catpv(buffer, " was not ");
    sv_catpv(buffer, article(package));
    sv_catpv(buffer, " '");
    sv_catsv(buffer, package);
    sv_catpv(buffer, "' (it is ");
    sv_catpv(buffer, article(value));
    sv_catpv(buffer, " ");
    sv_catsv(buffer, value);
    sv_catpv(buffer, ")\n");
    validation_failure(buffer, options);
}

/* UNIVERSAL::can alike validation */
static void
validate_can(SV* value, SV* method, SV* id, HV* options)
{
    char *name;
    IV ok = 1;
    HV* pkg = NULL;

    /* some bits of this code are stolen from universal.c:
       XS_UNIVERSAL_can - beware that I've reformatted it and removed
       unused parts */
    if(SvGMAGICAL(value)) mg_get(value);

    if(!SvOK(value)) {
        if(!(SvROK(value) || (SvPOK(value) && SvCUR(value)))) ok = 0;
    }

    if(ok) {
        name = SvPV_nolen(method);
        if(SvROK(value)) {
            value = (SV*)SvRV(value);
            if(SvOBJECT(value)) pkg = SvSTASH(value);
        }
    } else {
        pkg = gv_stashsv(value, FALSE);
    }

    ok = 0;
    if(pkg) {
        GV *gv;

        gv = gv_fetchmethod_autoload(pkg, name, FALSE);
        if(gv && isGV(gv)) ok = 1;
    }
    /* end of stolen code */

    if(!ok) {
        SV* buffer;

        buffer = sv_2mortal(newSVsv(id));
        sv_catpv(buffer, " to ");
        sv_catsv(buffer, get_called(options));
        sv_catpv(buffer, " does not have the method: '");
        sv_catsv(buffer, method);
        sv_catpv(buffer, "'\n");
        validation_failure(buffer, options);
    }
}

/* validates specific parameter using supplied parameter specification */
static void
validate_one_param(SV* value, HV* spec, SV* id, HV* options)
{
    SV** temp;

    /* check type */
    if(temp = hv_fetch(spec, "type", 4, 0)) {
        IV type;

        SvGETMAGIC(*temp);
        type = get_type(value);
        if(! (type & SvIV(*temp))) {
            SV* buffer;
            SV* is;
            SV* allowed;

            buffer = sv_2mortal(newSVsv(id));
            sv_catpv(buffer, " to ");
            sv_catsv(buffer, get_called(options));
            sv_catpv(buffer, " was ");
            is = typemask_to_string(type);
            allowed = typemask_to_string(SvIV(*temp));
            sv_catpv(buffer, article(is));
            sv_catpv(buffer, " '");
            sv_catsv(buffer, is);
            sv_catpv(buffer, "', which is not one of the allowed types: ");
            sv_catsv(buffer, allowed);
            sv_catpv(buffer, "\n");
            validation_failure(buffer, options);
        }
    }

    /* check isa */
    if(temp = hv_fetch(spec, "isa", 3, 0)) {
        SvGETMAGIC(*temp);
        if(SvROK(*temp) && SvTYPE(SvRV(*temp)) == SVt_PVAV) {
            IV i;

            for(i = 0; i <= av_len((AV*) SvRV(*temp)); i ++) {
                SV* package;

                package = *av_fetch((AV*) SvRV(*temp), i, 1);
                SvGETMAGIC(package);
                validate_isa(value, package, id, options);
            }
        } else {
            validate_isa(value, *temp, id, options);
        }
    }

    /* check can */
    if(temp = hv_fetch(spec, "can", 3, 0)) {
        SvGETMAGIC(*temp);
        if(SvROK(*temp) && SvTYPE(SvRV(*temp)) == SVt_PVAV) {
            IV i;

            for(i = 0; i <= av_len((AV*) SvRV(*temp)); i ++) {
                SV* method;

                method = *av_fetch((AV*) SvRV(*temp), i, 1);
                SvGETMAGIC(method);
                validate_can(value, method, id, options);
            }
        } else {
            validate_can(value, *temp, id, options);
        }
    }

    /* let callbacks to do their tests */
    if(temp = hv_fetch(spec, "callbacks", 9, 0)) {
        SvGETMAGIC(*temp);
        if(SvROK(*temp) && SvTYPE(SvRV(*temp)) == SVt_PVHV) {
            HE* he;

            hv_iterinit((HV*) SvRV(*temp));
            while(he = hv_iternext((HV*) SvRV(*temp))) {
                if(SvROK(HeVAL(he)) && SvTYPE(SvRV(HeVAL(he))) == SVt_PVCV) {
                    SV* ok;
                    dSP;

                    PUSHMARK(SP);
                    XPUSHs(value);
                    PUTBACK;
                    if(!perl_call_sv(SvRV(HeVAL(he)), G_SCALAR)) {
                        croak("Subroutine did not return anything");
                    }
                    SPAGAIN;
                    ok = POPs;
                    PUTBACK;

                    SvGETMAGIC(ok);

                    if(! SvTRUE(ok)) {
                        SV* buffer;

                        buffer = sv_2mortal(newSVsv(id));
                        sv_catpv(buffer, " to ");
                        sv_catsv(buffer, get_called(options));
                        sv_catpv(buffer, " did not pass the '");
                        sv_catsv(buffer, HeSVKEY_force(he));
                        sv_catpv(buffer, "' callback\n");
                        validation_failure(buffer, options);
                    }
                } else {
                    SV* buffer;

                    buffer = sv_2mortal(newSVpv("callback '", 0));
                    sv_catsv(buffer, HeSVKEY_force(he));
                    sv_catpv(buffer, "' for ");
                    sv_catsv(buffer, get_called(options));
                    sv_catpv(buffer, " is not a subroutine reference\n");
                    validation_failure(buffer, options);
                }
            }
        } else {
            SV* buffer;

            buffer = sv_2mortal(newSVpv("'callbacks' validation parameter for '", 0));
            sv_catsv(buffer, get_called(options));
            sv_catpv(buffer, " must be a hash reference\n");
            validation_failure(buffer, options);
        }
    }

    if(temp = hv_fetch(spec, "regex", 5, 0)) {
        IV has_regex = 0;
        IV ok;
        dSP;
  
        SvGETMAGIC(*temp);
        if(SvPOK(*temp)) {
          has_regex = 1;
        } else if(SvROK(*temp)) {
            SV* svp;

            svp = (SV*)SvRV(*temp);

            if (SvMAGICAL(svp) && mg_find(svp, PERL_MAGIC_qr)) {
                has_regex = 1;
            }
        }

        if(!has_regex) {
            SV* buffer;

            buffer = sv_2mortal(newSVpv("'regex' validation parameter for '", 0));
            sv_catsv(buffer, get_called(options));
            sv_catpv(buffer, " must be a string or qr// regex\n");
            validation_failure(buffer, options);

            return;
        }

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs(value);
        PUSHs(*temp);
        PUTBACK;
        perl_call_pv("Params::Validate::_check_regex_from_xs", G_SCALAR);
        SPAGAIN;
        ok = POPi;
        PUTBACK;

        if(!ok) {
            SV* buffer;

            buffer = sv_2mortal(newSVsv(id));
            sv_catpv(buffer, " to ");
            sv_catsv(buffer, get_called(options));
            sv_catpv(buffer, " did not pass regex check\n");
            validation_failure(buffer, options);
        }
    }
}

/* appends one hash to another (not deep copy) */
static void
append_hash2hash(HV* in, HV* out)
{
    HE* he;

    hv_iterinit(in);
    while(he = hv_iternext(in)) {
        if(!hv_store_ent(out, HeSVKEY_force(he),
                         SvREFCNT_inc(HeVAL(he)), HeHASH(he))) {
            SvREFCNT_dec(HeVAL(he));
            croak("Cannot add new key to hash");
        }
    }
}

/* convert array to hash */
static HV*
convert_array2hash(AV* in) {
    IV i;
    HV* out;

    out = (HV*) sv_2mortal((SV*) newHV());
    for(i = 0; i <= av_len(in); i += 2) {
        SV* key;
        SV* value;

        key = *av_fetch(in, i, 1);
        SvGETMAGIC(key);
        value = *av_fetch(in, i + 1, 1);
        SvGETMAGIC(value);
        if(! hv_store_ent(out, key, SvREFCNT_inc(value), 0)) {
            SvREFCNT_dec(value);
            croak("Cannot add new key to hash");
        }
    }

    return out;
}

/* get current Params::Validate options */
static HV*
get_options(HV* options)
{
    HV* OPTIONS;
    HV* ret;
    HE* he;
    SV** temp;
    char* pkg;

    ret = (HV*) sv_2mortal((SV*) newHV());

    /* gets caller's package name */

    pkg = CopSTASHPV(PL_curcop);
    if(pkg == Nullch) {
        pkg = "main";
    }

    /* get package specific options */
    OPTIONS = perl_get_hv("Params::Validate::OPTIONS", 1);
    if(temp = hv_fetch(OPTIONS, pkg, strlen(pkg), 0)) {
        SvGETMAGIC(*temp);
        if(SvROK(*temp) && SvTYPE(SvRV(*temp)) == SVt_PVHV) {
            if(options) {
                append_hash2hash((HV*) SvRV(*temp), ret);
            } else {
                return (HV*) SvRV(*temp);
            }
        }
    }
    if(options) {
        append_hash2hash(options, ret);
    }

    return ret;
}

/* convert parameter names when 'ignore_case' or 'strip_leading'
   options are set */
static HV*
normalize_named(HV* p, HV* options)
{
    SV** temp;
    IV ignore_case;
    SV* strip_leading;
    STRLEN len_sl;
    char* rawstr_sl;

    if(temp = hv_fetch(options, "ignore_case", 11, 0)) {
        SvGETMAGIC(*temp);
        ignore_case = SvTRUE(*temp);
    } else {
        ignore_case = 0;
    }
    if(temp = hv_fetch(options, "strip_leading", 13, 0)) {
        SvGETMAGIC(*temp);
        if(SvOK(*temp)) strip_leading = *temp;
        if(strip_leading) {
            rawstr_sl = SvPV(strip_leading, len_sl);
        }
    } else {
        strip_leading = NULL;
    }

    if(ignore_case || strip_leading) {
        HE* he;
        HV* p1;

        p1 = (HV*) sv_2mortal((SV*) newHV());
        hv_iterinit(p);
        while(he = hv_iternext(p)) {
            STRLEN len;
            char* rawstr;
            SV* sv;

            sv = HeSVKEY_force(he);
            if(ignore_case) {
                IV i;

                rawstr = SvPV(sv, len);
                for(i = 0; i < len; i ++) {
                    /* should this account for UTF8 strings? */
                    *(rawstr + i) = toLOWER(*(rawstr + i));
                }
                sv = sv_2mortal(newSVpvn(rawstr, len));
            }
            if(strip_leading) {
                rawstr = SvPV(sv, len);
                if(len > len_sl && strnEQ(rawstr_sl, rawstr, len_sl)) {
                    sv = sv_2mortal(newSVpvn(rawstr + len_sl, len - len_sl));
                }
            }
            if(! hv_store_ent(p1, sv, SvREFCNT_inc(HeVAL(he)), 0)) {
                SvREFCNT_dec(HeVAL(he));
                croak("Cannot add new key to hash");
            }
        }
        return p1;
    }
     
    return p;
}

static HV*
validate(HV* p, HV* specs, HV* options)
{
    AV* missing;
    AV* unmentioned;
    HE* he;
    HE* he1;
    HV* ret;
    IV allow_extra;
    SV** temp;

    /* normalize parameters */
    p = normalize_named(p, options);

    if(temp = hv_fetch(options, "allow_extra", 11, 0)) {
        SvGETMAGIC(*temp);
        allow_extra = SvTRUE(*temp);
    } else {
        allow_extra = 0;
    }

    /* find extra parameters and validate good parameters */
    if(GIMME_V != G_VOID) ret = (HV*) sv_2mortal((SV*) newHV());
    if(!NO_VALIDATE) unmentioned = (AV*) sv_2mortal((SV*) newAV());
    hv_iterinit(p);
    while(he = hv_iternext(p)) {
        SvGETMAGIC(HeVAL(he));

        /* put the parameter into return hash */
        if(GIMME_V != G_VOID) {
            if(!hv_store_ent(ret, HeSVKEY_force(he), SvREFCNT_inc(HeVAL(he)),
                             HeHASH(he))) {
                SvREFCNT_dec(HeVAL(he));
                croak("Cannot add new key to hash");
            }
        }

        if(!NO_VALIDATE) {
            /* check if this parameter is defined in spec and if it is
               then validate it using spec */
            if(he1 = hv_fetch_ent(specs, HeSVKEY_force(he), 0, HeHASH(he))) {
                SvGETMAGIC(HeVAL(he1));
                if(SvROK(HeVAL(he1)) && SvTYPE(SvRV(HeVAL(he1))) == SVt_PVHV) {
                    SV* buffer;
                    HV* spec;

                    spec = (HV*) SvRV(HeVAL(he1));
                    buffer = sv_2mortal(newSVpv("The '", 0));
                    sv_catsv(buffer, HeSVKEY_force(he));
                    sv_catpv(buffer, "' parameter");
                    validate_one_param(HeVAL(he), spec, buffer, options);
                }
            } else if(!allow_extra) {
                av_push(unmentioned, SvREFCNT_inc(HeSVKEY_force(he)));
            }
        }
        if(!NO_VALIDATE && av_len(unmentioned) > -1) {
            SV* buffer;
            IV i;

            buffer = sv_2mortal(newSVpv("The following parameter", 0));
            if(av_len(unmentioned) != 0) {
                sv_catpv(buffer, "s were ");
            } else {
                sv_catpv(buffer, " was ");
            }
            sv_catpv(buffer, "passed in the call to ");
            sv_catsv(buffer, get_called(options));
            sv_catpv(buffer, " but ");
            if(av_len(unmentioned) != 0) {
                sv_catpv(buffer, "were ");
            } else {
                sv_catpv(buffer, "was ");
            }
            sv_catpv(buffer, "not listed in the validation options: ");
            for(i = 0; i <= av_len(unmentioned); i ++) {
                sv_catsv(buffer, *av_fetch(unmentioned, i, 1));
                if(i < av_len(unmentioned)) {
                    sv_catpv(buffer, " ");
                }
            }
            sv_catpv(buffer, "\n");
            
            validation_failure(buffer, options);
        }
    }

    /* find missing parameters */
    if(!NO_VALIDATE) missing = (AV*) sv_2mortal((SV*) newAV());
    hv_iterinit(specs);
    while(he = hv_iternext(specs)) {
        HV* spec;
        SV* value;

        /* get extended param spec if available */
        if(SvROK(HeVAL(he)) && SvTYPE(SvRV(HeVAL(he))) == SVt_PVHV) {
            spec = (HV*) SvRV(HeVAL(he));
        } else {
            spec = NULL;
        }

        /* test for parameter existance  */
        if(hv_exists_ent(p, HeSVKEY_force(he), HeHASH(he))) {
            continue;
        }

        /* parameter may not be defined but we may have default */
        if(spec && (temp = hv_fetch(spec, "default", 7, 0))) {
            SV* value;

            SvGETMAGIC(*temp);
            value = sv_2mortal(newSVsv(*temp));

            /* make sure that parameter is put into return hash */
            if(GIMME_V != G_VOID) {
                if(!hv_store_ent(ret, HeSVKEY_force(he),
                                 SvREFCNT_inc(value), HeHASH(he))) {
                    SvREFCNT_dec(value);
                    croak("Cannot add new key to hash");
                }
            }

            continue;
        }

        /* find if missing paramater is mandatory */
        if(!NO_VALIDATE) {
            SV** temp;

            if(spec) {
                if(temp = hv_fetch(spec, "optional", 8, 0)) {
                    SvGETMAGIC(*temp);
                    if(SvTRUE(*temp)) continue;
                }
            } else if(!SvTRUE(HeVAL(he))) {
                continue;
            }
            av_push(missing, SvREFCNT_inc(HeSVKEY_force(he)));
        }
    }
    if(!NO_VALIDATE && av_len(missing) > -1) {
        SV* buffer;
        IV i;

        buffer = sv_2mortal(newSVpv("Mandatory parameter", 0));
        if(av_len(missing) > 0) {
            sv_catpv(buffer, "s ");
        } else {
            sv_catpv(buffer, " ");
        }
        for(i = 0; i <= av_len(missing); i ++) {
            sv_catpvf(buffer, "'%s'",
                      SvPV_nolen(*av_fetch(missing, i, 0)));
            if(i < av_len(missing)) {
                sv_catpv(buffer, ", ");
            }
        }
        sv_catpv(buffer, " missing in call to ");
        sv_catsv(buffer, get_called(options));
        sv_catpv(buffer, "\n");

        validation_failure(buffer, options);
    }

    return ret;
}

void
validate_pos_failure(IV pnum, IV min, IV max, HV* options)
{
    SV* buffer;
    SV** temp;
    IV allow_extra;

    if(temp = hv_fetch(options, "allow_extra", 11, 0)) {
        SvGETMAGIC(*temp);
        allow_extra = SvTRUE(*temp);
    } else {
        allow_extra = 0;
    }

    buffer = sv_2mortal(newSViv(pnum + 1));
    if(pnum != 0) {
        sv_catpv(buffer, " parameters were passed to ");
    } else {
        sv_catpv(buffer, " parameter was passed to ");
    }
    sv_catsv(buffer, get_called(options));
    sv_catpv(buffer, " but ");
    if(!allow_extra) {
        if(min != max) {
            sv_catpvf(buffer, "%d - %d", (int) min + 1, (int) max + 1);
        } else {
            sv_catpvf(buffer, "%d", (int) max + 1);
        }
    } else {
        sv_catpvf(buffer, "at least %d", (int) min + 1);
    }
    if((allow_extra ? min : max) != 0) {
        sv_catpv(buffer, " were expected\n");
    } else {
        sv_catpv(buffer, " was expected\n");
    }

    validation_failure(buffer, options);
}

static AV*
validate_pos(AV* p, AV* specs, HV* options)
{
    AV* ret;
    SV* buffer;
    SV* value;
    SV* spec;
    SV** temp;
    IV i;
    IV complex_spec;
    IV allow_extra;
    IV min;
    IV max;
    IV limit;

    /* iterate through all parameters and validate them */
    if(GIMME_V != G_VOID) ret = (AV*) sv_2mortal((SV*) newAV());
    min = -1;
    for(i = 0; i <= av_len(specs); i ++) {
        spec = *av_fetch(specs, i, 1);
        SvGETMAGIC(spec);
        complex_spec = (SvROK(spec) && SvTYPE(SvRV(spec)) == SVt_PVHV);

        if(complex_spec) {
            if(temp = hv_fetch((HV*) SvRV(spec), "optional", 8, 0)) {
                SvGETMAGIC(*temp);
                if(!SvTRUE(*temp)) min = i;
            } else {
                min = i;
            }
        } else {
            if(SvTRUE(spec)) min = i;
        }

        if(i <= av_len(p)) {
            value = *av_fetch(p, i, 1);
            SvGETMAGIC(value);
            if(!NO_VALIDATE && complex_spec) {
                buffer = sv_2mortal(newSVpvf("Parameter #%d", (int) i + 1));
                validate_one_param(value, (HV*) SvRV(spec), buffer, options);
            }
            if(GIMME_V != G_VOID) av_push(ret, SvREFCNT_inc(value));
        } else if(complex_spec &&
                  (temp = hv_fetch((HV*) SvRV(spec), "default", 7, 0))) {
            SvGETMAGIC(*temp);
            if(GIMME_V != G_VOID) av_push(ret, SvREFCNT_inc(*temp));
        } else {
            if(i == min) {
                validate_pos_failure(av_len(p), min, av_len(specs), options);
            }
        }
    }

    /* test for extra parameters */
    if(av_len(p) > av_len(specs)) {
        if(temp = hv_fetch(options, "allow_extra", 11, 0)) {
            SvGETMAGIC(*temp);
            allow_extra = SvTRUE(*temp);
        } else {
            allow_extra = 0;
        }
        if(allow_extra) {
            /* put all additional parameters into return array */
            if(GIMME_V != G_VOID) {
                for(i = av_len(specs) + 1; i <= av_len(p); i ++) {
                    value = *av_fetch(p, i, 1);
                    SvGETMAGIC(value);
                    av_push(ret, SvREFCNT_inc(value));
                }
            }
        } else {
            validate_pos_failure(av_len(p), min, av_len(specs), options);
        }
    }

    return ret;
}

MODULE = Params::Validate               PACKAGE = Params::Validate

BOOT:
bootinit();

void
validate(p, specs)
        SV* p
        SV* specs
    PROTOTYPE: \@$
    PPCODE:
        HV* ret;
        AV* pa;
        HV* ph;

        if(NO_VALIDATE && GIMME_V == G_VOID) return;

        if(!SvROK(p) || !(SvTYPE(SvRV(p)) == SVt_PVAV)) {
            croak("Expecting array reference as first parameter");
        }
        if(!SvROK(specs) || !(SvTYPE(SvRV(specs)) == SVt_PVHV)) {
            croak("Expecting hash reference as second parameter");
        }

        pa = (AV*) SvRV(p);
        ph = NULL;
        if(av_len(pa) == 0) {
            /* we were called as validate( @_, ... ) where @_ has a
               single element, a hash reference */
            SV* value;

            value = *av_fetch(pa, 0, 1);
            SvGETMAGIC(value);
            if(SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVHV) {
                ph = (HV*) SvRV(value);
            }
        }
        if(!ph) {
            ph = convert_array2hash(pa);
        }

        ret = validate(ph, (HV*) SvRV(specs), get_options(NULL));
        RETURN_HASH(ret);

void
validate_pos(p, ...)
        SV* p
    PROTOTYPE: \@@
    PPCODE:
        AV* specs;
        AV* ret;
        IV i;

        if(NO_VALIDATE && GIMME_V == G_VOID) return;

        if(!SvROK(p) || !(SvTYPE(SvRV(p)) == SVt_PVAV)) {
            croak("Expecting array reference as first parameter");
        }
        specs = (AV*) sv_2mortal((SV*) newAV());
        av_extend(specs, items);
        for(i = 1; i < items; i ++) {
            if(!av_store(specs, i - 1, SvREFCNT_inc(ST(i)))) {
                SvREFCNT_dec(ST(i));
                croak("Cannot store value in array");
            }
        }

        ret = validate_pos((AV*) SvRV(p), specs, get_options(NULL));
        RETURN_ARRAY(ret);

void
validate_with(...)
    PPCODE:
        HV* p;
        SV* params;
        SV* spec;
        IV i;

        if(NO_VALIDATE && GIMME_V == G_VOID) return;

        /* put input list into hash */
        p = (HV*) sv_2mortal((SV*) newHV());
        for(i = 0; i < items; i += 2) {
            SV* key;
            SV* value;

            key = ST(i);
            if(i + 1 < items) {
                value = ST(i + 1);
            } else {
                value = &PL_sv_undef;
            }
            if(! hv_store_ent(p, key, SvREFCNT_inc(value), 0)) {
                SvREFCNT_dec(value);
                croak("Cannot add new key to hash");
            }
        }

        params = *hv_fetch(p, "params", 6, 1);
        SvGETMAGIC(params);
        spec = *hv_fetch(p, "spec", 4, 1);
        SvGETMAGIC(spec);

        if(SvROK(spec) && SvTYPE(SvRV(spec)) == SVt_PVAV) {
            if(SvROK(params) && SvTYPE(SvRV(params)) == SVt_PVAV) {
                AV* ret;

                ret = validate_pos((AV*) SvRV(params), (AV*) SvRV(spec),
                                   get_options(p));
                RETURN_ARRAY(ret);
            } else {
                croak("Expecting array reference in 'params'");
            }
        } else if(SvROK(spec) && SvTYPE(SvRV(spec)) == SVt_PVHV) {
            HV* hv;
            HV* ret;

            if(SvROK(params) && SvTYPE(SvRV(params)) == SVt_PVHV) {
                hv = (HV*) SvRV(params);
            } else if(SvROK(params) && SvTYPE(SvRV(params)) == SVt_PVAV) {
                hv = convert_array2hash((AV*) SvRV(params));
            } else {
                croak("Expecting array or hash reference in 'params'");
            }

            ret = validate(hv, (HV*) SvRV(spec), get_options(p));
            RETURN_HASH(ret);
        } else {
            croak("Expecting array or hash reference in 'spec'");
        }
