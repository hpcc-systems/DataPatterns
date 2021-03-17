IMPORT ^ as DataPatterns;

filePath := '~class::pfb::out::vehiclereexpanded';

ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));