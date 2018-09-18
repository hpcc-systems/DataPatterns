/***
 * Function macro that leverages DataPatterns to return a string defining the
 * best ECL record structure for input data.
 *
 * @param   inFile          The dataset to process; REQUIRED
 * @param   sampling        A positive integer representing a percentage of
 *                          inFile to examine, which is useful when analyzing a
 *                          very large dataset and only an estimatation is
 *                          sufficient; valid range for this argument is
 *                          1-100; values outside of this range will be
 *                          clamped; OPTIONAL, defaults to 100 (which indicates
 *                          that the entire dataset will be analyzed)
 *
 * @return  A recordset defining the best ECL record structure for the data.
 *          Each record will contain one field declaration, and the list of
 *          declarations will be wrapped with RECORD and END strings.  This
 *          makes the result suitable for copying and pasting.
 */
EXPORT BestRecordStructure(inFile, sampling = 100) := FUNCTIONMACRO
    IMPORT Std;

    LOCAL patternRes := DataPatterns.Profile(inFile, features := 'best_ecl_types', sampleSize := sampling);

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