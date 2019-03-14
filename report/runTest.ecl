IMPORT ^ as DataPatterns;

filePath := '~h3::crowdingclean';

r := RECORD
  string68 address;
  real8 lat;
  real8 lng;
  unsigned3 dt_first_seen;
  unsigned1 deliverable;
  unsigned1 addr_type;
  unsigned1 drop;
  unsigned3 movetoscount;
  unsigned2 localmovetoscount;
  unsigned2 firstlocationcount;
  unsigned1 zombiecount;
  unsigned3 personwithssncount;
  unsigned3 personwithdobcount;
  unsigned2 suddenmovetoscount;
  real4 movetosmediandistance;
  unsigned2 movetosmedianmonthdiff;
  real8 meanmoveage;
  unsigned2 medianmoveage;
  unsigned2 secrangecount;
  unsigned2 secrangeinstancecount;
  unsigned2 invalidsecrangepeoplecount;
  unsigned2 secrangepeoplecount;
  unsigned2 undeliverablesecrangeinstancecount;
  unsigned1 secrangeinstancedropcnt;
  unsigned1 dobpct;
  real8 zombiepct;
 END;


ds := DATASET(filePath, r, FLAT);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));
