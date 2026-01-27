IMPORT ^ as DataPatterns;

filePath := '~regress::multi::person';

ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));