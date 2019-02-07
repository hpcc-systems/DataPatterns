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
 * @param   emitTransform   Boolean governing whether the function emits a
 *                          TRANSFORM function that could be used to rewrite
 *                          the dataset into the 'best' record definition;
 *                          OPTIONAL, defaults to FALSE.
 *
 * @return  A recordset defining the best ECL record structure for the data.
 *          Each record will contain one field declaration, and the list of
 *          declarations will be wrapped with RECORD and END strings.  If the
 *          emitTransform argument was TRUE, there will also be a set of
 *          records that that comprise a stand-alone TRANSFORM function.  This
 *          format makes the result suitable for copying and pasting.
 */
EXPORT BestRecordStructure(inFile, sampling = 100, emitTransform = FALSE) := FUNCTIONMACRO
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

    LOCAL layoutSet := ['NewLayout := RECORD'] + SET(fields, s) + ['END;'];

    // Helper function for determining if old and new data types need
    // explicit type casting
    LOCAL NeedCoercion(STRING oldType, STRING newType) := FUNCTION
        GenericType(STRING theType) := MAP
            (
                theType[..6] = 'string'         =>  'string',
                theType[..7] = 'qstring'        =>  'string',
                theType[..9] = 'varstring'      =>  'string',
                theType[..3] = 'utf'            =>  'string',
                theType[..7] = 'unicode'        =>  'string',
                theType[..10] = 'varunicode'    =>  'string',
                theType[..4] = 'data'           =>  'data',
                theType[..7] = 'boolean'        =>  'boolean',
                'numeric'
            );

        oldGenericType := GenericType(oldType);
        newGenericType := GenericType(newType);

        RETURN oldGenericType != newGenericType;
    END;

    // Subset of fields that need explicit type casting
    LOCAL differentTypes := patternRes(NeedCoercion(given_attribute_type, best_attribute_type));

    // Explicit type casting statements
    LOCAL coercedTransformStatements := PROJECT
        (
            differentTypes,
            TRANSFORM
                (
                    OutRec,
                    SELF.s := '    SELF.' + LEFT.attribute + ' := (' + Std.Str.ToUppercase(LEFT.best_attribute_type) + ')r.' + LEFT.attribute + ';';
                )
        );

    // Final transform step, if needed
    LOCAL coercedTransformStatementSet := IF
        (
            COUNT(patternRes) != COUNT(differentTypes),
            SET(coercedTransformStatements, s) + ['    SELF := r;'],
            SET(coercedTransformStatements, s)
        );

    // Final transform function
    LOCAL transformSet := IF
        (
            (BOOLEAN)emitTransform,
            ['//======================================', 'NewLayout MakeNewLayout(OldLayout r) := TRANSFORM'] + coercedTransformStatementSet + ['END;'],
            []
        );

    RETURN DATASET(layoutSet + transformSet, OutRec);
ENDMACRO;