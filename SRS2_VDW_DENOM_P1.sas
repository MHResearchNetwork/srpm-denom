*******************************************************************************;
* PROGRAM DETAILS                                                             *;
*   Filename: SRS2_VDW_DENOM_P1.sas (developed in SAS v9.4 for Windows)       *;
*   Purpose:  Pull VDW-based denominator of internal, Epic-based adult out-   *;
*             patient clinic visits that occurred during 1/1/2009-6/30/2015   *;
*             and were associated with one or more of the following: 1) MH    *;
*             department, 2) MH specialty provider, 3) MH specialty procedure *;
*             or 4) selected MH diagnoses.                                    *;
*   Updated:  January 30, 2017                                                *;
*******************************************************************************;

*******************************************************************************;
* INITIAL PROGRAM SETUP:                                                      *;
*   - %include the full path to your local StdVars file.                      *;
*   - %let root = location of this SAS program.                               *;
*   - %let start = either 01JAN2009 or DDMONYYYY-formatted date of local Epic *;
*     implementation, whichever happened more recently.                       *;
*******************************************************************************;
%include "\\path\StdVars.sas";

%let root = \\path\SRS2_VDW_DENOM_P1;

%let start = 01JAN2009;

*******************************************************************************;

%let v = P1;

data _null_;
  x = index("&root", "SRS2_VDW_DENOM_&v");
  if x = 0 then call symput('root', strip("&root" || "/SRS2_VDW_DENOM_&v"));
run;

libname loc "&root/LOCAL";

libname ret "&root/RETURN";

proc datasets kill lib=work memtype=data nolist;
quit;

%macro dsdelete(dsname);
  %if %sysfunc(exist(&dsname)) = 1 %then %do;
    proc sql;
      drop table &dsname;
    quit;
  %end;
%mend dsdelete;

options errors=0 formchar="|----|+|---+=|-/\<>*" mprint nodate nofmterr
  nomlogic nonumber nosymbolgen
;

resetline;

proc printto log="&root/LOCAL/SRS2_VDW_DENOM_&v._&_SITEABBR..log" new;
run;

*******************************************************************************;
* Pull VDW-based denominator of internal, Epic-based adult outpatient clinic  *;
* visits that occurred during 1/1/2009 (or since Epic implementation) through *;
* 6/30/2015 and were associated with one or more of the following: 1) mental  *;
* health (MH) department, 2) MH specialty provider, 3) MH specialty procedure *;
* or 4) selected MH diagnoses.                                                *;
*******************************************************************************;
proc sql;
  create table mh_ute_raw as
  select 
    /* STANDARD VDW VARIABLES */
    distinct enc.mrn
    , enc.adate
    , enc.enc_id
    , enc.department
    , enc.provider
    , dem.birth_date
    , spec.specialty
    , px.px
    , dx.dx
    /**************************************************************************
    * BEGIN LOCAL CODE: Store available Clarity encounter IDs if available in *
    * VDW Encounter, Px, and/or Dx tables.                                    *
    **************************************************************************/
    , case
        when enc.clarity_enc_id > 0 then enc.clarity_enc_id 
        else . 
      end as enc_peci
    , case
        when px.clarity_enc_id > 0 then px.clarity_enc_id 
        else .
      end as px_peci
    , case
        when dx.clarity_enc_id > 0 then dx.clarity_enc_id
        else .
      end as dx_peci
    /* END LOCAL CODE */
  from &_vdw_utilization as enc
    left join &_vdw_demographic as dem
      on enc.mrn = dem.mrn 
    left join &_vdw_provider_specialty as spec
      on enc.provider = spec.provider
    left join &_vdw_px as px
      on enc.enc_id = px.enc_id
    left join &_vdw_dx as dx
      on enc.enc_id = dx.enc_id
  where "&start"d <= enc.adate <= '30JUN2015'd
    and enc.enctype = 'AV'
    and enc.encounter_subtype = 'OC'
    and ( enc.department = 'MH'
        or spec.specialty in ('MEN' 'PSY' 'SOC')
        or (  px.px_codetype = 'C4' and length(strip(px.px)) = 5 
              and (px.px like '9079%' or px.px like '908%') )
        or (  dx.dx_codetype = '09' and (dx.dx like '29%' or dx.dx like '30%'
              or dx.dx like '31%') ) )
    /* BEGIN LOCAL CODE: If necessary, limit to internal, Epic-based visits. */
    and enc.int_ext = 'I'
    /* END LOCAL CODE */
  ;

  delete *
  from mh_ute_raw
  where birth_date = . 
    or intck('year', birth_date, adate, 'c') < 13
  ;
quit;

data mh_ute_recode;
  set mh_ute_raw;
  length depression bipolar schizophrenia anxiety autism attn_def personality
    sub_abuse 3
  ;
  array mhdx{8} depression--sub_abuse;
  do i = 1 to 8;
    mhdx{i} = 0;
  end;
  drop i;
  if dx in: ('296.2' '296.3' '296.82' '298.0' '300.4' '301.12' '309.0'
    '309.1' '309.28' '311') then depression + 1
  ;
    else if dx in: ('296.0' '296.1' '296.4' '296.5' '296.6' '296.7' '296.80'
      '296.81' '296.89' '301.11' '301.13') then bipolar + 1
    ;
    else if dx =: '295' then schizophrenia + 1;
    else if dx in: ('300.0' '300.2' '300.3' '309.21' '309.24' '309.81')
      then anxiety + 1
    ;
    else if dx =: '299' then autism + 1;
    else if dx =: '314' then attn_def + 1;
    else if dx =: '301' then personality + 1;
    else if dx in: ('291' '292' '303' '304' '305') then sub_abuse + 1;
  length mh_dept mh_spec mh_proc mh_diag 3;
  mh_dept = 0;
  mh_spec = 0;
  mh_proc = 0;
  mh_diag = 0;
  if department = 'MH' then mh_dept + 1;
  if specialty in ('MEN' 'PSY' 'SOC') then mh_spec + 1;
  if length(strip(px)) = 5 and px in: ('9079' '908') then do;
    px_num = input(px, 5.);
    if px_num in (90791:90862) then mh_proc + 1;
  end;
  drop px_num;
  do j = 1 to 8;
    mh_diag = max(mh_diag, mhdx{j});
  end;
  drop j;
run;

proc summary data=mh_ute_recode nway;
  class enc_id mrn birth_date adate department provider;
  var depression bipolar schizophrenia anxiety autism attn_def personality
    sub_abuse mh_dept mh_spec mh_proc mh_diag
  ;
  output out=mh_ute_sum (drop=_type_ rename=(_freq_=vdw_ute_recs)) max=;
run;

proc sql;
  delete *
  from mh_ute_sum
  where sum(mh_dept, mh_spec, mh_proc, mh_diag) = 0;
quit;

proc freq data=mh_ute_sum noprint;
  tables mh_dept * mh_spec * mh_proc * mh_diag / list out=mh_ute_freq;
run;

*******************************************************************************;
* Create PDF file for local review. Note: Small cell sizes and totals will be *;
* suppressed in data set to be returned to lead programmer.                   *;
*******************************************************************************;
ods listing close;

ods noproctitle;

ods escapechar='^';

ods pdf file="&root/LOCAL/SRS2_VDW_DENOM_SUM_&v._&_siteabbr..pdf" notoc
  style=minimal
;

proc print data=mh_ute_freq noobs label;
  title1 "&_siteabbr SRS2 Denominator &v: VDW-based population of internal,
 Epic-based¹, MH-related² outpatient clinic encounters³ that occurred between
 &start and 30JUN2015 among patients aged 13+ years"
  ;
  title2;
  title3 'How did encounters come to be included in sampling frame?';
  title4;
  var mh_dept mh_spec mh_proc mh_diag COUNT PERCENT / style=[cellwidth=.85in];
  label mh_dept='DEPARTMENT' mh_spec='PROVIDER SPECIALTY' mh_proc='PROCEDURE'
    mh_diag='DIAGNOSIS' count='N' percent='%'
  ;
  format count comma12. percent 6.1;
  sum count percent;
  footnote "Filename: &root/LOCAL/SRS2_VDW_DENOM_SUM_&v._&_siteabbr..pdf";
run;

ods pdf text='^{newline 2}1) As defined by local VDW programmer';

ods pdf text='^{newline}2) Encounters where: department is mental health;
 provider specialty is mental health, psychiatry, or social services;
 procedure code indicates a mental health specialty visit; or diagnosis code
 indicates depressive, bipolar, schizophrenia spectrum, anxiety, autism
 spectrum, attention deficit, personality, or substance use disorder'
;

ods pdf text='^{newline}3) Unique across person, date, encounter type, provider,
 encounter subtype, facility code, and appointment time'
;

ods pdf close;

*******************************************************************************;
* Mask small cell sizes in SAS data set to be returned to lead programmer.    *;
*******************************************************************************;
%dsdelete(ret.SRS2_DENOM_SUM_&v._&_siteabbr);

data ret.SRS2_DENOM_SUM_&v._&_siteabbr;
  set mh_ute_freq;
  if count < &lowest_count then count = .;
run;

proc printto;
run;

*******************************************************************************;
* Save all relevant utilization records (incl. Dx, Px, PECIs) for later use.  *;
*******************************************************************************;
proc sort data=mh_ute_recode out=mh_ute_sort;
  by enc_id;
run;

%dsdelete(loc.SRS2_DENOM_FULL_&v._&_siteabbr);

data loc.SRS2_DENOM_FULL_&v._&_siteabbr;
  merge mh_ute_sort (in=a) mh_ute_sum (in=b keep=enc_id);
  by enc_id;
  if a and b;
run;

*******************************************************************************;
* END OF PROGRAM                                                              *;
*******************************************************************************;
