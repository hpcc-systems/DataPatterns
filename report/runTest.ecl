IMPORT ^ as DataPatterns;

filePath := 'heart_disease_uci.csv';

ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), CSV);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));