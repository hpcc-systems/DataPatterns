/***
 * Function macro that leverages DataPatterns to return a string defining the
 * best ECL record structure for input data.
 *
 * @param   inFile      The dataset to process
 *
 * @return  A string defining the best ECL record structure for the data.
 *          The string is suitable for copying and pasting into ECL code.
 */
EXPORT BestRecordStructure(inFile) := FUNCTIONMACRO
    IMPORT Std;

    LOCAL patternRes := DataPatterns.Profile(inFile, features := 'best_ecl_types');

    LOCAL fields := PROJECT
        (
            patternRes,
            TRANSFORM
                (
                    {STRING s},
                    SELF.s := '    ' + Std.Str.ToUppercase(LEFT.best_attribute_type) + ' ' + LEFT.attribute + ';'
                )
        );

    LOCAL fieldsStr := Std.Str.CombineWords(SET(fields, s), '\n');

    LOCAL fullStr := 'RECORD\n' + fieldsStr + '\nEND;';

    RETURN fullStr;
ENDMACRO;