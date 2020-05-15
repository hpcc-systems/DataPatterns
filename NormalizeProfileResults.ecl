/**
 * This function macro rewrites the dataset result from a call to Profile()
 * into a more normalized format.  This format is ideal
 * for saving as a separate file, possibly to be used to compare against a
 * future profile run against a new version of the original dataset.
 *
 * The result will be in the following format:
 *
 *      RECORD
 *          STRING      attribute;  // Field from profiled dataset
 *          STRING      key;        // Field from profile results
 *          STRING      value;      // Value from profile results
 *      END;
 *
 * The actual 'key' values that appear in these results will depend on which
 * 'features' were supplied to the profile call.
 *
 * The value for attributes with child datasets in the profile result is
 * still a single string.  The string is composed of pipe ('|') delimited
 * values from each child record, and those may further be delimited with
 * colons if there are additional fields.
 *
 * Also, note that all profile values are coerced to STRING values.
 */
EXPORT NormalizeProfileResults(profileResults) := FUNCTIONMACRO
    LOADXML('<xml/>');
    #EXPORTXML(profileResultsFields, RECORDOF(profileResults));
    #UNIQUENAME(recLevel);
    #UNIQUENAME(fieldCount);
    #SET(fieldCount, 0);

    IMPORT Std;

    #UNIQUENAME(ResultRec);
    LOCAL %ResultRec% := RECORD
        STRING      attribute;
        STRING      key;
        STRING      value;
    END;

    #UNIQUENAME(Xpose);
    LOCAL %ResultRec% %Xpose%(RECORDOF(profileResults) aRec, UNSIGNED2 fieldIndex) := TRANSFORM
        SELF.attribute := (STRING)aRec.attribute;
        SELF.key := CHOOSE
            (
                fieldIndex,
                #SET(recLevel, 0)
                #FOR(profileResultsFields)
                    #FOR(Field)
                        #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                            #SET(recLevel, %recLevel% + 1)
                            #IF(%'@name'% IN ['popular_patterns', 'rare_patterns', 'modes', 'cardinality_breakdown', 'correlations'])
                                #SET(fieldCount, %fieldCount% + 1)
                                %'@name'%,
                            #END
                        #ELSEIF(%{@isEnd}% = 1)
                            #SET(recLevel, %recLevel% - 1)
                        #ELSEIF(%recLevel% = 0)
                            #IF(%'@name'% != 'attribute')
                                #SET(fieldCount, %fieldCount% + 1)
                                %'@name'%,
                            #END
                        #END
                    #END
                #END
                ''
            );
        SELF.value := CHOOSE
            (
                fieldIndex,
                #SET(recLevel, 0)
                #FOR(profileResultsFields)
                    #FOR(Field)
                        #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                            #SET(recLevel, %recLevel% + 1)
                            #IF(%'@name'% IN ['popular_patterns', 'rare_patterns'])
                                Std.Str.CombineWords(SET(aRec.%@name%, TRIM(data_pattern) + ':' + (STRING)rec_count), '|'),
                            #ELSEIF(%'@name'% IN ['modes', 'cardinality_breakdown'])
                                Std.Str.CombineWords(SET(aRec.%@name%, TRIM(value) + ':' + (STRING)rec_count), '|'),
                            #ELSEIF(%'@name'% = 'correlations')
                                Std.Str.CombineWords(SET(aRec.%@name%, TRIM(attribute) + ':' + (STRING)corr), '|'),
                            #END
                        #ELSEIF(%{@isEnd}% = 1)
                            #SET(recLevel, %recLevel% - 1)
                        #ELSEIF(%recLevel% = 0)
                            #IF(%'@name'% != 'attribute')
                                #IF(REGEXFIND('(boolean)', %'@type'%))
                                    IF(aRec.%@name%, 'true', 'false'),
                                #ELSE
                                    (STRING)aRec.%@name%,
                                #END
                            #END
                        #END
                    #END
                #END
                ''
            );
    END;

    #UNIQUENAME(result);
    LOCAL %result% := NORMALIZE(profileResults, %fieldCount%, %Xpose%(LEFT, COUNTER));

    RETURN %result%;
ENDMACRO;
