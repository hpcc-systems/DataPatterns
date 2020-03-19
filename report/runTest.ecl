IMPORT ^ as DataPatterns;

filePath := '~progguide::exampledata::people';

ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));
