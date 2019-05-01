IMPORT ^ as DataPatterns;

filePath := '~stock_data::cleaned_data';

ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

profileResults := DataPatterns.Profile(ds);

OUTPUT(profileResults, ALL, NAMED('profileResults'));