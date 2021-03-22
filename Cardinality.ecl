/***
 * Function macro for computing the cardinality of values within all or part
 * of a dataset.  The output is a dataset containing the following information
 * for each processed attribute:
 *
 *      attribute               The name of the field
 *      value                   A value from the field as a UTF-8 string
 *      rec_count               The number of records analyzed in the dataset
 *                              that contained that particular value
 *
 * The result will be returned sorted by (attribute, -rec_count, value).
 *
 * The result from this function macro can be considered an expanded or more
 * complete version of what is found in the 'cardinality_breakdown' result from
 * DataPatterns.Profile().  Here, there is no limit on the number of unique
 * values that will be captured.  Also, as can be seen from the return structure
 * outlined above, the result is a simple three-field dataset (no child datasets
 * to process).
 *
 * Function parameters:
 *
 * @param   inFile          The dataset to process; this could be a child
 *                          dataset (e.g. inFile.childDS); REQUIRED
 * @param   fieldListStr    A string containing a comma-delimited list of
 *                          attribute names to process; use an empty string to
 *                          process all attributes in inFile; OPTIONAL,
 *                          defaults to an empty string
 * @param   sampleSize      A positive integer representing a percentage of
 *                          inFile to examine, which is useful when analyzing a
 *                          very large dataset and only an estimated cardinality
 *                          is sufficient; valid range for this argument is 1-100;
 *                          values outside of this range will be clamped; OPTIONAL,
 *                          defaults to 100 (which indicates that the entire dataset
 *                          will be analyzed)
 */
EXPORT Cardinality(inFile,
                   fieldListStr = '\'\'',
                   sampleSize = 100) := FUNCTIONMACRO
    LOADXML('<xml/>');

    #UNIQUENAME(temp);                      // Ubiquitous "contains random things"
    #UNIQUENAME(scalarFields);              // Contains a delimited list of scalar attributes (full names) along with their indexed positions
    #UNIQUENAME(explicitScalarFields);      // Contains a delimited list of scalar attributes (full names) without indexed positions
    #UNIQUENAME(childDSFields);             // Contains a delimited list of child dataset attributes (full names) along with their indexed positions
    #UNIQUENAME(fieldCount);                // Contains the number of fields we've seen while processing record layouts
    #UNIQUENAME(recLevel);                  // Will be used to determine at which level we are processing
    #UNIQUENAME(fieldStack);                // String-based stack telling us whether we're within an embedded dataset or record
    #UNIQUENAME(namePrefix);                // When processing child records and datasets, contains the leading portion of the attribute's full name
    #UNIQUENAME(fullName);                  // The full name of an attribute
    #UNIQUENAME(needsDelim);                // Boolean indicating whether we need to insert a delimiter somewhere
    #UNIQUENAME(namePos);                   // Contains character offset information, for parsing delimited strings
    #UNIQUENAME(namePos2);                  // Contains character offset information, for parsing delimited strings
    #UNIQUENAME(nameValue);                 // Extracted string value from a string
    #UNIQUENAME(nameValue2);                // Extracted string value from a string

    IMPORT Std;

    //--------------------------------------------------------------------------

    // Remove all spaces from field list so we can parse it more easily
    #UNIQUENAME(trimmedFieldList);
    LOCAL %trimmedFieldList% := TRIM((STRING)fieldListStr, ALL);

    // Typedefs
    #UNIQUENAME(Attribute_t);
    LOCAL %Attribute_t% := STRING;
    #UNIQUENAME(AttributeValue_t);
    LOCAL %AttributeValue_t% := UTF8;
    #UNIQUENAME(RecordCount_t);
    LOCAL %RecordCount_t% := UNSIGNED8;

    //--------------------------------------------------------------------------

    // Ungroup the given dataset, in case it was grouped
    #UNIQUENAME(ungroupedInFile);
    LOCAL %ungroupedInFile% := UNGROUP(inFile);

    // Clamp the sample size to something reasonable
    #UNIQUENAME(clampedSampleSize);
    LOCAL %clampedSampleSize% := MAX(1, MIN(100, (INTEGER)sampleSize));

    // Create a sample dataset if needed
    #UNIQUENAME(sampledData);
    LOCAL %sampledData% := IF
        (
            %clampedSampleSize% < 100,
            ENTH(%ungroupedInFile%, %clampedSampleSize%, 100, 1, LOCAL),
            %ungroupedInFile%
        );

    // Slim the dataset if the caller provided an explicit set of attributes;
    // note that explicit attributes within a top-level child dataset will
    // cause the entire top-level child dataset to be retained
    #UNIQUENAME(workingInFile);
    LOCAL %workingInFile% :=
        #IF(%trimmedFieldList% = '')
            %sampledData%
        #ELSE
            TABLE
                (
                    %sampledData%,
                    {
                        #SET(needsDelim, 0)
                        #SET(namePos, 1)
                        #SET(nameValue2, '')
                        #LOOP
                            #SET(temp, REGEXFIND('^([^,]+)', %trimmedFieldList%[%namePos%..], 1))
                            #IF(%'temp'% != '')
                                #SET(nameValue, REGEXFIND('^([^\\.]+)', %'temp'%, 1))
                                #IF(NOT REGEXFIND('\\b' + %'nameValue'% + '\\b', %'nameValue2'%))
                                    #IF(%'nameValue2'% != '')
                                        #APPEND(nameValue2, ',')
                                    #END
                                    #APPEND(nameValue2, %'nameValue'%)

                                    #IF(%needsDelim% = 1) , #END

                                    TYPEOF(%sampledData%.%nameValue%) %nameValue% := %nameValue%

                                    #SET(needsDelim, 1)
                                #END
                                #SET(namePos, %namePos% + LENGTH(%'temp'%) + 1)
                            #ELSE
                                #BREAK
                            #END
                        #END
                    }
                )
        #END;

    // Distribute the inbound dataset across all our nodes for faster processing
    #UNIQUENAME(distributedInFile);
    LOCAL %distributedInFile% := DISTRIBUTE(%workingInFile%, SKEW(0.05));

    #EXPORTXML(inFileFields, RECORDOF(%distributedInFile%));

    // Walk the slimmed dataset, pulling out top-level scalars and noting
    // child datasets
    #SET(scalarFields, '');
    #SET(childDSFields, '');
    #SET(fieldCount, 0);
    #SET(recLevel, 0);
    #SET(fieldStack, '');
    #SET(namePrefix, '');
    #SET(fullName, '');
    #FOR(inFileFields)
        #FOR(Field)
            #SET(fieldCount, %fieldCount% + 1)
            #IF(%{@isEnd}% != 1)
                // Adjust full name
                #SET(fullName, %'namePrefix'% + %'@name'%)
            #END
            #IF(%{@isRecord}% = 1)
                // Push record onto stack so we know what we're popping when we see @isEnd
                #SET(fieldStack, 'r' + %'fieldStack'%)
                #APPEND(namePrefix, %'@name'% + '.')
            #ELSEIF(%{@isDataset}% = 1)
                // Push dataset onto stack so we know what we're popping when we see @isEnd
                #SET(fieldStack, 'd' + %'fieldStack'%)
                #APPEND(namePrefix, %'@name'% + '.')
                #SET(recLevel, %recLevel% + 1)
                // Note the field index and field name so we can process it separately
                #IF(%'childDSFields'% != '')
                    #APPEND(childDSFields, ',')
                #END
                #APPEND(childDSFields, %'fieldCount'% + ':' + %'fullName'%)
                // Extract the child dataset into its own attribute so we can more easily
                // process it later
                #SET(temp, #MANGLE(%'fullName'%));
                LOCAL %temp% := NORMALIZE
                    (
                        %distributedInFile%,
                        LEFT.%fullName%,
                        TRANSFORM
                            (
                                RECORDOF(%distributedInFile%.%fullName%),
                                SELF := RIGHT
                            )
                    );
            #ELSEIF(%{@isEnd}% = 1)
                #SET(namePrefix, REGEXREPLACE('\\w+\\.$', %'namePrefix'%, ''))
                #IF(%'fieldStack'%[1] = 'd')
                    #SET(recLevel, %recLevel% - 1)
                #END
                #SET(fieldStack, %'fieldStack'%[2..])
            #ELSEIF(%recLevel% = 0)
                // Note the field index and full name of the attribute so we can process it
                #IF(%'scalarFields'% != '')
                    #APPEND(scalarFields, ',')
                #END
                #APPEND(scalarFields, %'fieldCount'% + ':' + %'fullName'%)
            #END
        #END
    #END

    // Collect the gathered full attribute names so we can walk them later
    #SET(explicitScalarFields, REGEXREPLACE('\\d+:', %'scalarFields'%, ''));

    // Define the record layout that will be used by the inner _Inner_Cardinality() call

    LOCAL OutputLayout := RECORD
        %Attribute_t%                   attribute;
        %AttributeValue_t%              value;
        %RecordCount_t%                 rec_count;
    END;

    //==========================================================================

    // This is the meat of the function macro that actually does the work;
    // it is called with various datasets and (possibly) explicit attributes
    // to process and the results will eventually be combined to form the
    // final result; the parameters largely match the Cardinality() call, with the
    // addition of a few parameters that help place the results into the
    // correct format; note that the name of this function macro is not wrapped
    // in a UNIQUENAME -- that is due to an apparent limitation in the ECL
    // compiler
    LOCAL _Inner_Cardinality(_inFile,
                             _fieldListStr,
                             _resultLayout,
                             _attrNamePrefix) := FUNCTIONMACRO
        #EXPORTXML(inFileFields, RECORDOF(_inFile));
        #UNIQUENAME(explicitFields);

        // Validate that attribute is okay for us to process (there is no explicit
        // attribute list or the name is in the list)
        #UNIQUENAME(_CanProcessAttribute);
        LOCAL %_CanProcessAttribute%(STRING attrName) := (_fieldListStr = '' OR REGEXFIND('(^|,)' + attrName + '(,|$)', _fieldListStr, NOCASE));

        // Collect a list of the top-level attributes that we can process
        #SET(needsDelim, 0);
        #SET(recLevel, 0);
        #SET(fieldStack, '');
        #SET(namePrefix, '');
        #SET(explicitFields, '');
        #FOR(inFileFields)
            #FOR(Field)
                #IF(%{@isRecord}% = 1)
                    #SET(fieldStack, 'r' + %'fieldStack'%)
                    #APPEND(namePrefix, %'@name'% + '.')
                #ELSEIF(%{@isDataset}% = 1)
                    #SET(fieldStack, 'd' + %'fieldStack'%)
                    #SET(recLevel, %recLevel% + 1)
                #ELSEIF(%{@isEnd}% = 1)
                    #IF(%'fieldStack'%[1] = 'd')
                        #SET(recLevel, %recLevel% - 1)
                    #ELSE
                        #SET(namePrefix, REGEXREPLACE('\\w+\\.$', %'namePrefix'%, ''))
                    #END
                    #SET(fieldStack, %'fieldStack'%[2..])
                #ELSEIF(%recLevel% = 0)
                    #IF(%_CanProcessAttribute%(%'namePrefix'% + %'@name'%))
                        #IF(%needsDelim% = 1)
                            #APPEND(explicitFields, ',')
                        #END
                        #APPEND(explicitFields, %'namePrefix'% + %'@name'%)
                        #SET(needsDelim, 1)
                    #END
                #END
            #END
        #END

        #UNIQUENAME(dataInfo);
        LOCAL %dataInfo% :=
            #SET(recLevel, 0)
            #SET(fieldStack, '')
            #SET(namePrefix, '')
            #SET(needsDelim, 0)
            #SET(fieldCount, 0)
            #FOR(inFileFields)
                #FOR(Field)
                    #IF(%{@isRecord}% = 1)
                        #SET(fieldStack, 'r' + %'fieldStack'%)
                        #APPEND(namePrefix, %'@name'% + '.')
                    #ELSEIF(%{@isDataset}% = 1)
                        #SET(fieldStack, 'd' + %'fieldStack'%)
                        #SET(recLevel, %recLevel% + 1)
                    #ELSEIF(%{@isEnd}% = 1)
                        #IF(%'fieldStack'%[1] = 'd')
                            #SET(recLevel, %recLevel% - 1)
                        #ELSE
                            #SET(namePrefix, REGEXREPLACE('\\w+\\.$', %'namePrefix'%, ''))
                        #END
                        #SET(fieldStack, %'fieldStack'%[2..])
                    #ELSEIF(%recLevel% = 0)
                        #IF(%_CanProcessAttribute%(%'namePrefix'% + %'@name'%))
                            #SET(fieldCount, %fieldCount% + 1)
                            #IF(%needsDelim% = 1) + #END

                            IF(EXISTS(_inFile),
                                PROJECT
                                    (
                                        TABLE
                                            (
                                                _inFile,
                                                {
                                                    %Attribute_t%       attribute := _attrNamePrefix + %'namePrefix'% + %'@name'%,
                                                    %AttributeValue_t%  value := (%AttributeValue_t%)_inFile.#EXPAND(%'namePrefix'% + %'@name'%),
                                                    %RecordCount_t%     rec_count := COUNT(GROUP)
                                                },
                                                _inFile.#EXPAND(%'namePrefix'% + %'@name'%),
                                                MERGE
                                            ),
                                            TRANSFORM(_resultLayout, SELF := LEFT)
                                    ),
                                DATASET
                                    (
                                        1,
                                        TRANSFORM
                                            (
                                                _resultLayout,
                                                SELF.attribute := _attrNamePrefix + %'namePrefix'% + %'@name'%,
                                                SELF.value := (%AttributeValue_t%)'',
                                                SELF := []
                                            )
                                    )
                                )

                            #SET(needsDelim, 1)
                        #END
                    #END
                #END
            #END

            // Insert empty value for syntax checking
            #IF(%fieldCount% = 0)
                DATASET([], _resultLayout)
            #END;

        RETURN #IF(%fieldCount% > 0) %dataInfo% #ELSE DATASET([], _resultLayout) #END;
    ENDMACRO;

    //==========================================================================

    // Call _Inner_Cardinality() with the given input dataset top-level scalar attributes,
    // then again for each child dataset that has been found; combine the
    // results of all the calls
    #UNIQUENAME(collectedResults);
    LOCAL %collectedResults% :=
        #IF(%'explicitScalarFields'% != '')
            _Inner_Cardinality
                (
                    GLOBAL(%distributedInFile%),
                    %'explicitScalarFields'%,
                    OutputLayout,
                    ''
                )
        #ELSE
            DATASET([], OutputLayout)
        #END
        #UNIQUENAME(dsNameValue)
        #SET(namePos, 1)
        #LOOP
            #SET(dsNameValue, REGEXFIND('^([^,]+)', %'childDSFields'%[%namePos%..], 1))
            #IF(%'dsNameValue'% != '')
                #SET(nameValue, REGEXFIND(':([^:]+)$', %'dsNameValue'%, 1))
                // Extract a list of fields within this child dataset if necessary
                #SET(explicitScalarFields, '')
                #SET(needsDelim, 0)
                #SET(namePos2, 1)
                #LOOP
                    #SET(temp, REGEXFIND('^([^,]+)', %trimmedFieldList%[%namePos2%..], 1))
                    #IF(%'temp'% != '')
                        #SET(nameValue2, REGEXFIND('^' + %'nameValue'% + '\\.([^,]+)', %'temp'%, 1))
                        #IF(%'nameValue2'% != '')
                            #IF(%needsDelim% = 1)
                                #APPEND(explicitScalarFields, ',')
                            #END
                            #APPEND(explicitScalarFields, %'nameValue2'%)
                            #SET(needsDelim, 1)
                        #END
                        #SET(namePos2, %namePos2% + LENGTH(%'temp'%) + 1)
                    #ELSE
                        #BREAK
                    #END
                #END
                // The child dataset should have been extracted into its own
                // local attribute; reference it during our call to the inner
                // cardinality function macro
                #SET(temp, #MANGLE(%'nameValue'%))
                + _Inner_Cardinality
                    (
                        GLOBAL(%temp%),
                        %'explicitScalarFields'%,
                        OutputLayout,
                        %'nameValue'% + '.'
                    )
                #SET(namePos, %namePos% + LENGTH(%'dsNameValue'%) + 1)
            #ELSE
                #BREAK
            #END
        #END;

    // Put the combined _Inner_Cardinality() results in the right order and layout
    #UNIQUENAME(finalData);
    LOCAL %finalData% := PROJECT(SORT(%collectedResults%, attribute, -rec_count, value), OutputLayout);

    RETURN %finalData%;
ENDMACRO;
