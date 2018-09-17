/***
 * Function macro that leverages DataPatterns to return a string defining the
 * best ECL record structure for input data.
 *
 * @param   inFile      The dataset to process
 *
 * @return  A recordset defining the best ECL record structure for the data.
 *          Each record will contain one field declaration, and the list of
 *          declarations will be wrapped with RECORD and END strings.  This
 *          makes the result suitable for copying and pasting.
 */
EXPORT BestRecordStructure(inFile) := FUNCTIONMACRO
    IMPORT Std;

    LOCAL samplePercentage := IF(COUNT(inFile) <= 1000000, 100, 100000000 / COUNT(inFile));
    LOCAL patternRes := DataPatterns.Profile(inFile, features := 'best_ecl_types', sampleSize := samplePercentage);

    LOCAL OutRec := {STRING s};

    LOCAL fields := PROJECT
        (
            patternRes,
            TRANSFORM
                (
                    OutRec,
                    SELF.s := '    ' + Std.Str.ToUppercase(LEFT.best_attribute_type) + ' ' + LEFT.attribute + ';'
                )
        );
    
    LOCAL entries := ['RECORD'] + SET(fields, s) + ['END;'];

    RETURN DATASET(entries, OutRec);
ENDMACRO;