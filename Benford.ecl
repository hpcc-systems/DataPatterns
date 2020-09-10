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
 * distributions.  Included in each row is a chi-squared computation for that
 * row indicating how well the computed result matches the expected result
 * (if the chi-squared value exceeds the one shown in the --EXPEECTED-- row
 * then the row DOES NOT follow Benford's Law).
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
 *              DECIMAL4_1  one;
 *              DECIMAL4_1  two;
 *              DECIMAL4_1  three;
 *              DECIMAL4_1  four;
 *              DECIMAL4_1  five;
 *              DECIMAL4_1  six;
 *              DECIMAL4_1  seven;
 *              DECIMAL4_1  eight;
 *              DECIMAL4_1  nine;
 *              DECIMAL5_3  chi_squared;
 *          END;
 *
 * The named digit fields (e.g. "one" and "two" and so on) represent the
 * non-zero leading digits found in the associated attribute.  The values
 * that appear there are percentages.
 *
 * The first row of the results will show the expected values for the named
 * digits, with "--EXPECTED--" showing as the attribute name.
 */
EXPORT Benford(inFile, fieldListStr = '\'\'', sampleSize = 100) := FUNCTIONMACRO
    // Chi-squared critical values for 8 degrees of freedom at various probabilities
    // Probability:     0.90    0.95    0.975   0.99    0.999
    // Critical value:  13.362  15.507  17.535  20.090  26.125
    #UNIQUENAME(CHI_SQUARED_CRITICAL_VALUE);
    #SET(CHI_SQUARED_CRITICAL_VALUE, 20.090); // 99% probability

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

    // Temp field name we will use to ensure proper ordering of results
    #UNIQUENAME(idField);

    // One-record dataset containing expected Benford results, per-digit
    #UNIQUENAME(expectedDS);
    LOCAL %expectedDS% := DATASET
        (
            [{0, '--EXPECTED--', 30.1, 17.6, 12.5, 9.7, 7.9, 6.7, 5.8, 5.1, 4.6, 0}],
            {
                UNSIGNED2   %idField%,
                STRING64    attribute,
                DECIMAL4_1  one,
                DECIMAL4_1  two,
                DECIMAL4_1  three,
                DECIMAL4_1  four,
                DECIMAL4_1  five,
                DECIMAL4_1  six,
                DECIMAL4_1  seven,
                DECIMAL4_1  eight,
                DECIMAL4_1  nine,
                DECIMAL5_3  chi_squared
            }
        );

    // This will be used later as a datatype in a function signature
    #UNIQUENAME(DataRec);
    LOCAL %DataRec% := RECORDOF(%expectedDS%);

    // Create a dataset composed of the expectedDS and a row for each
    // field we will be processing
    #UNIQUENAME(interimResult);
    LOCAL %interimResult% := %expectedDS%
        #UNIQUENAME(recLevel)
        #SET(recLevel, 0)
        #UNIQUENAME(fieldNum)
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
                            %workingInFile%((INTEGER)%@name% != 0),
                            {
                                UNSIGNED2   %idField% := %fieldNum%,
                                STRING64    attribute := %'@name'%,
                                DECIMAL4_1  one := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 1) / COUNT(GROUP) * 100,
                                DECIMAL4_1  two := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 2) / COUNT(GROUP) * 100,
                                DECIMAL4_1  three := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 3) / COUNT(GROUP) * 100,
                                DECIMAL4_1  four := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 4) / COUNT(GROUP) * 100,
                                DECIMAL4_1  five := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 5) / COUNT(GROUP) * 100,
                                DECIMAL4_1  six := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 6) / COUNT(GROUP) * 100,
                                DECIMAL4_1  seven := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 7) / COUNT(GROUP) * 100,
                                DECIMAL4_1  eight := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 8) / COUNT(GROUP) * 100,
                                DECIMAL4_1  nine := COUNT(GROUP, %FirstDigit%((STRING)%@name%) = 9) / COUNT(GROUP) * 100,
                                DECIMAL5_3  chi_squared := 0 // Fill in later
                            },
                            MERGE
                        )
                #END
            #END
        #END;

    // Helper function for computing chi-squared values from the interim results
    #UNIQUENAME(ComputeChiSquared);
    LOCAL %ComputeChiSquared%(%DataRec% expected, %DataRec% actual) := FUNCTION
        Term(DECIMAL4_1 e, DECIMAL4_1 o) := ((o - e) * (o - e)) / e;

        RETURN Term(expected.one, actual.one)
                + Term(expected.two, actual.two)
                + Term(expected.three, actual.three)
                + Term(expected.four, actual.four)
                + Term(expected.five, actual.five)
                + Term(expected.six, actual.six)
                + Term(expected.seven, actual.seven)
                + Term(expected.eight, actual.eight)
                + Term(expected.nine, actual.nine);
    END;

    // Insert the chi-squared results
    #UNIQUENAME(chiSquaredResult);
    LOCAL %chiSquaredResult% := PROJECT
        (
            %interimResult%,
            TRANSFORM
                (
                    RECORDOF(LEFT),
                    SELF.chi_squared := IF(LEFT.%idField% > 0, %ComputeChiSquared%(%expectedDS%[1], LEFT), %CHI_SQUARED_CRITICAL_VALUE%),
                    SELF := LEFT
                )
        );

    // Sort by the ID field to put everything in the proper order, and remove the ID
    // field from the final result
    #UNIQUENAME(finalResult);
    LOCAL %finalResult% := PROJECT(SORT(%chiSquaredResult%, %idField%), {RECORDOF(%chiSquaredResult%) - [%idField%]});

    RETURN %finalResult%;
ENDMACRO;
