/**
 * This function macro rewrites the dataset result from a call to Profile()
 * or ProfileFromPath() into a more normalized format.  This format is ideal
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
 * Child datasets from the profile results (modes, cardinality breakdowns,
 * text patterns, and correlations) are not copied to the normalized format.
 * The actual 'key' values that appear in these results will depend on which
 * 'features' were supplied to the profile call.
 *
 * Also, note that all profile values are coerced to STRING values.
 */
EXPORT NormalizeProfileResults(profileResults) := FUNCTIONMACRO
    LOADXML('<xml/>');
    #EXPORTXML(profileResultsFields, RECORDOF(profileResults));
    #UNIQUENAME(recLevel);
    #UNIQUENAME(fieldNum);
    #SET(fieldNum, 0);

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
                        #ELSEIF(%{@isEnd}% = 1)
                            #SET(recLevel, %recLevel% - 1)
                        #ELSEIF(%recLevel% = 0)
                            #IF(%'@name'% != 'attribute')
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
                        #ELSEIF(%{@isEnd}% = 1)
                            #SET(recLevel, %recLevel% - 1)
                        #ELSEIF(%recLevel% = 0)
                            #IF(%'@name'% != 'attribute')
                                #SET(fieldNum, %fieldNum% + 1)
                                #IF(REGEXFIND('(boolean)', %'@type'%))
                                    IF(aRec.%@name%, 'true', 'false')
                                #ELSE
                                    (STRING)aRec.%@name%
                                #END,
                            #END
                        #END
                    #END
                #END
                ''
            );
    END;

    #UNIQUENAME(result);
    LOCAL %result% := NORMALIZE(profileResults, %fieldNum%, %Xpose%(LEFT, COUNTER));

    RETURN %result%;
ENDMACRO;
