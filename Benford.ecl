/**
 * Benford's law, also called the Newcomb–Benford law, the law of anomalous
 * numbers, or the first-digit law, is an observation about the frequency
 * distribution of leading digits in many real-life sets of numerical data.
 *
 * Benford's law doesn't apply to every set of numbers, but it usually applies
 * to large sets of naturally occurring numbers with some connection like:
 *
 *      Companies' stock market values
 *      Data found in texts — like the Reader's Digest, or a copy of Newsweek
 *      Demographic data, including state and city populations
 *      Income tax data
 *      Mathematical tables, like logarithms
 *      River drainage rates
 *      Scientific data
 *
 * The law usually doesn't apply to data sets that have a stated minimum and
 * maximum, like interest rates or hourly wages. If numbers are assigned,
 * rather than naturally occurring, they will also not follow the law. Examples
 * of assigned numbers include: zip codes, telephone numbers and Social
 * Security numbers.
 *
 * For more information: https://en.wikipedia.org/wiki/Benford%27s_law
 *
 * This function computes the distribution of non-zero significant digits
 * within one or more attributes in a dataset and displays the result, one
 * attribute per row, with an "expected" row showing the expected
 * distributions.
 *
 * @param   inFile          The dataset to process; REQUIRED
 * @param   fieldListStr    A string containing a comma-delimited list of
 *                          attribute names to process; note that attributes
 *                          listed here must be top-level attributes (not child
 *                          records or child datasets); use an empty string to
 *                          process all top-level attributes in inFile;
 *                          OPTIONAL, defaults to an empty string
 * @param   sampleSize      A positive integer representing a percentage of
 *                          inFile to examine, which is useful when analyzing a
 *                          very large dataset and only an estimated data
 *                          analysis is sufficient; valid range for this
 *                          argument is 1-100; values outside of this range
 *                          will be clamped; OPTIONAL, defaults to 100 (which
 *                          indicates that the entire dataset will be analyzed)
 *
 * @return  A new dataset with the following record structure:
 *
 *          RECORD
 *              STRING64    attribute;
 *              DECIMAL5_2  one;
 *              DECIMAL5_2  two;
 *              DECIMAL5_2  three;
 *              DECIMAL5_2  four;
 *              DECIMAL5_2  five;
 *              DECIMAL5_2  six;
 *              DECIMAL5_2  seven;
 *              DECIMAL5_2  eight;
 *              DECIMAL5_2  nine;
 *          END;
 *
 * The named digit fields (e.g. "one" and "two" and so on) represent the
 * non-zero leading digits found in the associated attribute.  The values
 * that appear there are percentages.
 *
 * The first row of the results will show the expected values for the named
 * digits, with "--EXPECTED--" showing as the attribute name.
 *
 * @see
 */
EXPORT Benford(inFile, fieldListStr = '\'\'', sampleSize = 100) := FUNCTIONMACRO
    #UNIQUENAME(recLevel);
    #UNIQUENAME(fieldNum);

    // Remove all spaces from field list so we can parse it more easily
    #UNIQUENAME(trimmedFieldList);
    LOCAL %trimmedFieldList% := TRIM(fieldListStr, ALL);

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
    // note that the TABLE function will fail if %trimmedFieldList% cites an
    // attribute that is a child dataset (this is an ECL limitation)
    #UNIQUENAME(workingInFile);
    LOCAL %workingInFile% :=
        #IF(%trimmedFieldList% = '')
            %sampledData%
        #ELSE
            TABLE(%sampledData%, {#EXPAND(%trimmedFieldList%)})
        #END;

    // Grab the total record count
    #UNIQUENAME(inFileRecCount);
    LOCAL %inFileRecCount% := COUNT(%workingInFile%);

    #EXPORTXML(inFileFields, RECORDOF(%workingInFile%));

    // Helper function that returns the first non-zero digit in a string
    #UNIQUENAME(FirstDigit);
    LOCAL UNSIGNED1 %FirstDigit%(VARSTRING s) := EMBED(C++)
        unsigned char   v = 0;
        const char*     ch = s;

        while (*ch)
        {
            if (isdigit(*ch) && *ch != '0')
            {
                v = *ch - 48;
                break;
            }
            else
            {
                ++ch;
            }
        }

        return v;
    ENDEMBED;

    #UNIQUENAME(idField);
    #UNIQUENAME(interimResult);
    LOCAL %interimResult% :=
        DATASET
            (
                [{0, '--EXPECTED--', 30.1, 17.6, 12.5, 9.7, 7.9, 6.7, 5.8, 5.1, 4.6}],
                {
                    UNSIGNED2   %idField%,
                    STRING64    attribute,
                    DECIMAL5_2  one,
                    DECIMAL5_2  two,
                    DECIMAL5_2  three,
                    DECIMAL5_2  four,
                    DECIMAL5_2  five,
                    DECIMAL5_2  six,
                    DECIMAL5_2  seven,
                    DECIMAL5_2  eight,
                    DECIMAL5_2  nine
                }
            )
        #SET(recLevel, 0)
        #SET(fieldNum, 0)
        #FOR(inFileFields)
            #FOR(Field)
                #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                    #SET(recLevel, %recLevel% + 1)
                #ELSEIF(%{@isEnd}% = 1)
                    #SET(recLevel, %recLevel% - 1)
                #ELSEIF(%recLevel% = 0)
                    #SET(fieldNum, %fieldNum% + 1)
                    + TABLE
                        (
                            %workingInFile%,
                            {
                                UNSIGNED2   %idField% := %fieldNum%,
                                STRING64    attribute := %'@name'%,
                                DECIMAL5_2  one := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 1) / %inFileRecCount% * 100,
                                DECIMAL5_2  two := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 2) / %inFileRecCount% * 100,
                                DECIMAL5_2  three := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 3) / %inFileRecCount% * 100,
                                DECIMAL5_2  four := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 4) / %inFileRecCount% * 100,
                                DECIMAL5_2  five := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 5) / %inFileRecCount% * 100,
                                DECIMAL5_2  six := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 6) / %inFileRecCount% * 100,
                                DECIMAL5_2  seven := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 7) / %inFileRecCount% * 100,
                                DECIMAL5_2  eight := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 8) / %inFileRecCount% * 100,
                                DECIMAL5_2  nine := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 9) / %inFileRecCount% * 100
                            },
                            MERGE
                        )
                #END
            #END
        #END;

    // Sort by the ID field to put everything in the proper order, and remove the ID
    // field from the final result
    #UNIQUENAME(finalResult);
    LOCAL %finalResult% := PROJECT(SORT(%interimResult%, %idField%), {RECORDOF(%interimResult%) - [%idField%]});

    RETURN %finalResult%;
ENDMACRO;
