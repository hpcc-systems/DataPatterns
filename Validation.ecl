EXPORT Validation := MODULE

    /**
     * Function that executes one or more value validation checks against a dataset
     * and appends the result in a well-structured format.
     *
     * Validation checks are defined within a semicolon-delimited STRING.  Each check
     * should be in the following format:
     *
     *      <test_name>:<test_ecl>
     *
     * 'test_name' should be a name somehow representing the check that is
     * being performed.  The name will be included in the appended data if the
     * check fails.  Names should start with a letter and may contain letters,
     * numbers, periods, dashes, and underscores.
     *
     * 'test_ecl' is ECL code that performs the test.  If a string literal is
     * included in the test then the apostrophes must be escaped because test
     * is being defined within a string.
     *
     * The ECL code used during the test is executed within the scope of a single
     * dataset record.  Syntax-wise, it is similar to creating an ECL filter clause.
     * Like a filter, the ECL should evaluate to a BOOLEAN result and what you want
     * to do is return TRUE if the data being tested is VALID.  Invalid results,
     * where the ECL returns FALSE, are what is appended to the dataset.
     *
     * Validate() imports the Std ECL library, so all standard library functions
     * are available for use within a test.  Also, because Validate() is a function
     * macro, any function that is in scope when Validate() is called may also be
     * used within a test.  This provides quite a bit of flexibility when it comes
     * to writing tests.
     *
     * Validate() also includes a few internally-defined functions for use within
     * your tests as a convenience:
     *
     *      OnlyDigits(s)       Convert a single argument to a UTF-8 string and remove
     *                          everything but numeric digits
     *
     *      OnlyChars(s)        Convert a single argument to a UTF-8 string and remove
     *                          everything but alphabetic characters
     *
     *      WithoutPunct(s)     Convert a single argument to a UTF-8 string and remove
     *                          all punctuation characters
     *
     *      Patternize(s)       Create a 'text pattern' from the single argument,
     *                          mapping character classes to a fixed palette:
     *                              lowercase character -> a
     *                              uppercase character -> A
     *                              numeric digit       -> 9
     *                              everything else     -> unchanged
     *
     *      StrLen(s)           Convert a single argument to a UTF-8 string and return
     *                          its length as an unsigned integer
     *
     *      IsOnlyDigits(s)     Return TRUE if every character in the value is a digit
     *
     *      IsOnlyUppercase(s)  Return TRUE if every character in the value is an
     *                          uppercase character
     *
     *      IsOnlyLowercase(s)  Return TRUE if every character in the value is a
     *                          lowercase character
     *
     *      IsDecimalNumber(s)  Return TRUE if the value is a number, possibly prefixed
     *                          by a negative sign, and possibly including a decimal
     *                          portion
     *
     * Example test specifications:
     *
     *      MyValueIsPos:my_value > 0 // my_value must be greater than zero
     *      SomeNumInRange:some_num BETWEEN 50 AND 100 // some_num must be 50..100
     *      FIPSLength:StrLen(fips) = 5 // length of FIPS code must be 5
     *      DatesOrdered:dateBegin <= dateEnd // make sure dates are not flipped
     *
     * Example specification citing the last two tests from above:
     *
     *      'FIPSLength:StrLen(fips) = 5;DatesOrdered:dateBegin <= dateEnd'
     *
     * Invocation information:
     *
     * @param   inFile                  The dataset to validate; REQUIRED
     * @param   specStr                 STRING defining the tests to execute
     *                                  (see above for details); REQUIRED
     * @param   validationRecNameStr    STRING defining the name of the child
     *                                  record to be appended to the dataset
     *                                  containing the results; OPTIONAL,
     *                                  defaults to 'validation_results'
     *
     * @return  The input dataset with the results of the validation checks
     *          appended to each row as a child record.  The child record will
     *          have the following layout:
     *
     *          RECORD
     *              UNSIGNED2       num_violations;
     *              SET OF STRING   violations;
     *          END;
     *
     *          The child record's name is normally validation_results but that
     *          can be overridden via the validationRecNameStr parameter.
     *
     *          The name of a faiing test will appear in the violations SET,
     *          and the total number of failed tests will be appear in
     *          num_violations.
     *
     * @see     Fix
     */
    EXPORT Validate(inFile, specStr, validationRecNameStr = '\'validation_results\'') := FUNCTIONMACRO
        IMPORT Std;
        LOADXML('<xml/>');
        #EXPORTXML(inFileFields, RECORDOF(inFile));

        //-----------------------------------------------------
        // Provide specific errors for bad arguments
        //-----------------------------------------------------

        #IF(TRIM((STRING)specStr, LEFT, RIGHT) = '')
            #ERROR('No tests supplied (specStr argument missing or an empty string)')
        #END

        #IF(TRIM((STRING)validationRecNameStr, LEFT, RIGHT) = '')
            #ERROR('validationRecNameStr argument cannot be an empty string')
        #END

        //-----------------------------------------------------
        // Helper coercion functions; these rewrite a value and can be used
        // to create a temporary value for testing; these are all reachable
        // from within validation specification tests
        //-----------------------------------------------------

        LOCAL OnlyDigits(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE('[^[:digit:]]', (STRING)s, '');
        ENDMACRO;

        LOCAL OnlyChars(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE(U8'[^[:alpha:]]', (UTF8)s, U8'', NOCASE);
        ENDMACRO;

        LOCAL WithoutPunct(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE(U8'[[:punct:]]', (UTF8)s, U8'', NOCASE);
        ENDMACRO;

        LOCAL Patternize(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE(U8'[[:digit:]]', REGEXREPLACE(U8'[[:lower:]]', REGEXREPLACE(U8'[[:upper:]]', (UTF8)s, U8'A'), U8'a'), U8'9');
        ENDMACRO;

        //-----------------------------------------------------
        // Helper test functions; these perform tests against a value;
        // all are reachable from within validation specification tests
        //-----------------------------------------------------

        LOCAL StrLen(s) := FUNCTIONMACRO
            RETURN LENGTH((UTF8)s);
        ENDMACRO;

        LOCAL IsOnlyDigits(s) := FUNCTIONMACRO
            RETURN REGEXFIND(U8'^[[:digit:]]+$', (UTF8)s);
        ENDMACRO;

        LOCAL IsOnlyUppercase(s) := FUNCTIONMACRO
            RETURN REGEXFIND(U8'^[[:upper:]]+$', (UTF8)s);
        ENDMACRO;

        LOCAL IsOnlyLowercase(s) := FUNCTIONMACRO
            RETURN REGEXFIND(U8'^[[:lower:]]+$', (UTF8)s);
        ENDMACRO;

        LOCAL IsDecimalNumber(s) := FUNCTIONMACRO
            RETURN REGEXFIND(U8'^-?(?:[[:digit:]]+(\\.[[:digit:]]*)?)|(?:[[:digit:]]*\\.[[:digit:]]+)$', (UTF8)s);
        ENDMACRO;

        //-----------------------------------------------------
        // Collect top-level field names into a regex pattern
        //-----------------------------------------------------

        #UNIQUENAME(topLevelFieldPattern);
        #SET(topLevelFieldPattern, '');
        #UNIQUENAME(recLevel);
        #SET(recLevel, 0);
        #FOR(inFileFields)
            #FOR(Field)
                #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                    #SET(recLevel, %recLevel% + 1)
                #ELSEIF(%{@isEnd}% = 1)
                    #SET(recLevel, %recLevel% - 1)
                #ELSEIF(%recLevel% = 0)
                    #IF(%'topLevelFieldPattern'% = '')
                        #APPEND(topLevelFieldPattern, '\\b(')
                    #ELSE
                        #APPEND(topLevelFieldPattern, '|')
                    #END
                    #APPEND(topLevelFieldPattern, %'{@name}'%)
                #END
            #END
        #END
        #IF(%'topLevelFieldPattern'% != '')
             #APPEND(topLevelFieldPattern, ')\\b')
        #END

        //-----------------------------------------------------
        // Define output record layout
        //-----------------------------------------------------

        #UNIQUENAME(validationRecName);
        #SET(validationRecName, (STRING)validationRecNameStr);

        #UNIQUENAME(ValidateRec);
        LOCAL %ValidateRec% := RECORD
            UNSIGNED2       num_violations;
            SET OF STRING   violations;
        END;

        #UNIQUENAME(OutRec);
        LOCAL %OutRec% := RECORD
            RECORDOF(inFile);
            %ValidateRec%   %validationRecName%;
        END;

        //-----------------------------------------------------
        // Rewrite test specifications into a single RHS ECL statement suitable for TRANSFORM;
        // construct individual tests in the form:
        //      IF(NOT(test), 'testName', '')
        // then make each test a SET element; finally, filter out the empty strings
        //-----------------------------------------------------

        #UNIQUENAME(tempStr);
        #UNIQUENAME(pos);
        #UNIQUENAME(numTests);
        #UNIQUENAME(testName);
        #UNIQUENAME(transformECL);
        #UNIQUENAME(oneECLTest);

        #UNIQUENAME(trimmedSpecStr);
        #SET(trimmedSpecStr, TRIM((STRING)specStr, LEFT, RIGHT));

        #SET(transformECL, '(SET OF STRING)[');
        #SET(pos, 1);
        #SET(numTests, 0);
        #LOOP
            #IF(%pos% < LENGTH(%'trimmedSpecStr'%))
                #SET(tempStr, REGEXFIND('^([^;]+)', %'trimmedSpecStr'%[%pos%..], 1))
                #IF(%'tempStr'% != '')
                    #SET(testName, TRIM(REGEXFIND('^ *([\\w\\.\\-_]+) *:', %'tempStr'%, 1), LEFT, RIGHT))
                    #IF(%'testName'% != '')
                        #SET(oneECLTest, TRIM(REGEXFIND(':(.+)', %'tempStr'%, 1), LEFT, RIGHT))
                        #IF(REGEXFIND('AllFieldsFilled\\(\\)', %'oneECLTest'%, NOCASE))
                            #SET(oneECLTest, '')
                            #SET(recLevel, 0);
                            #FOR(inFileFields)
                                #FOR(Field)
                                    #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                                        #SET(recLevel, %recLevel% + 1)
                                    #ELSEIF(%{@isEnd}% = 1)
                                        #SET(recLevel, %recLevel% - 1)
                                    #ELSEIF(%recLevel% = 0)
                                        #IF(%'oneECLTest'% != '')
                                            #APPEND(oneECLTest, ' AND ')
                                        #END
                                        #APPEND(oneECLTest, '(TRIM((STRING)' + %'{@name}'% + ', LEFT, RIGHT) != \'\')')
                                    #END
                                #END
                            #END
                        #END
                        #IF(%'oneECLTest'% != '')
                            #SET(oneECLTest, REGEXREPLACE(%'topLevelFieldPattern'%, %'oneECLTest'%, 'LEFT.$1', NOCASE))
                            #SET(oneECLTest, 'IF(NOT(' + %'oneECLTest'% + '), \'' + %'testName'% + '\', \'\')')
                            #SET(numTests, %numTests% + 1)
                            #IF(%numTests% > 1)
                                #APPEND(transformECL, ', ')
                            #END
                            #APPEND(transformECL, %'oneECLTest'%)
                        #END
                    #END
                #END
                #SET(pos, %pos% + LENGTH(%'tempStr'%) + 1)
            #ELSE
                #BREAK
            #END
        #END
        #APPEND(transformECL, ']');
        #SET(transformECL, 'SET(DATASET(' + %'transformECL'% +', {STRING s})(s != \'\'), s)');

        //-----------------------------------------------------
        // PROJECT through the input dataset, appending our validation transform results
        //-----------------------------------------------------

        #UNIQUENAME(result);
        LOCAL %result% := PROJECT
            (
                inFile,
                TRANSFORM
                    (
                        %OutRec%,
                        SELF.%validationRecName%.violations := %transformECL%,
                        SELF.%validationRecName%.num_violations := COUNT(SELF.%validationRecName%.violations),
                        SELF := LEFT
                    )
            );

        RETURN %result%;
    ENDMACRO;

    /**
     * Function that applies "fixes" to a dataset, where errors have ben
     * previously identified with the Validate() function from this module.
     *
     * Fixes are defined within a semicolon-delimited STRING.  Each fix should
     * be in the following format:
     *
     *      <membership_test>:<fix_ecl>
     *
     * 'membership_test' is a logical clause testing whether one or more tests
     * from the Validate() function is true for that record.  The presence of a
     * single test name means "this test was in violation for this record".
     * AND and OR operators may be used in conjunction with multiple test names
     * to refine the determination of what went wrong with the record.
     * NOT() may be used to invert a test (i.e. "this test was not found to
     * be in violation") and is most used in conjunction with another test.
     *
     * 'fix_ecl' is ECL code that fixes the problem.  The most basic fix is
     * redefining a field value (e.g. my_field := new_value_expression).
     * If a string literal is included in the test then the apostrophes must be
     * escaped because tes is being defined within a string.  If a REGEXFIND()
     * or REGEXREPLACE() function is used and anything within the pattern needs
     * to be escaped then the backslash must be double-escaped.  ECL already
     * requires a single escape (\\. or \\d) but including it in a test here
     * means you have to double-escape the backslash: \\\\. or \\\\d.
     *
     * The ECL code used during the fix is executed within the scope of a single
     * dataset record.  This means that the expression may reference any field
     * in the record.
     *
     * Fix() imports the Std ECL library, so all standard library functions
     * are available for use within a fix.  Also, because Fix() is a function
     * macro, any function that is in scope when Fix() is called may also be
     * used within a fix.
     *
     * Fix() also includes a few internally-defined functions for use within
     * your fixes as a convenience:
     *
     *      OnlyDigits(s)       Convert a single argument to a UTF-8 string and remove
     *                          everything but numeric digits
     *
     *      OnlyChars(s)        Convert a single argument to a UTF-8 string and remove
     *                          everything but alphabetic characters
     *
     *      WithoutPunct(s)     Convert a single argument to a UTF-8 string and remove
     *                          all punctuation characters
     *
     *      Swap(f1, f2)        Swap the contents of two named fields
     *
     *      SkipRecord()        Remove the current record from the dataset
     *
     * Given these test specifications used in Validate():
     *
     *      MyValueIsPos:my_value > 0 // my_value must be greater than zero
     *      SomeNumInRange:some_num BETWEEN 50 AND 100 // some_num must be 50..100
     *      FIPSLength:StrLen(fips) = 5 // length of FIPS code must be 5
     *      DatesOrdered:dateBegin <= dateEnd // make sure dates are not flipped
     *
     * Here some example fix specifications:
     *
     *      MyValueIsPos:my_value := 1 // my_value was < 1, so change it to 1
     *      SomeNumInRange AND MyValueIsPos:SkipRecord() // Both violations present; just omit record
     *      FIPSLength:fips := INTFORMAT((INTEGER)fips, 5, 1) // pad the value to 5 digits
     *      DatesOrdered:Swap(dateBegin, dateEnd) // swap values of dates
     *
     * Invocation information:
     *
     * @param   inFile                  The dataset to validate; this should
     *                                  contain the child record as appended
     *                                  by the Validate() function;  REQUIRED
     * @param   specStr                 STRING defining the fixes to execute
     *                                  (see above for details); REQUIRED
     * @param   validationRecNameStr    STRING defining the name of the child
     *                                  record appended to the dataset by the
     *                                  Validate() function; OPTIONAL, defaults
     *                                  to 'validation_results'
     *
     * @return  The input dataset with the fixes applied and stripped of the
     *          child record appended by Validate().  The structure of this
     *          dataset should be the same as the dataset originally supplied
     *          to the Validate() function.
     *
     * @see     Validate
     */
    EXPORT Fix(inFile, specStr, validationRecNameStr = '\'validation_results\'') := FUNCTIONMACRO
        IMPORT Std;
        LOADXML('<xml/>');
        #EXPORTXML(inFileFields, RECORDOF(inFile));

        //-----------------------------------------------------
        // Provide specific errors for bad arguments
        //-----------------------------------------------------

        #IF(TRIM((STRING)specStr, LEFT, RIGHT) = '')
            #ERROR('No tests supplied (specStr argument missing or an empty string)')
        #END

        #IF(TRIM((STRING)validationRecNameStr, LEFT, RIGHT) = '')
            #ERROR('validationRecNameStr argument cannot be an empty string')
        #END

        //-----------------------------------------------------
        // Helper coercion functions; these rewrite a value and can be used
        // to create a temporary value for testing; these are all reachable
        // from within validation specification tests
        //-----------------------------------------------------

        LOCAL OnlyDigits(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE('[^[:digit:]]', (STRING)s, '');
        ENDMACRO;

        LOCAL OnlyChars(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE(U8'[^[:alpha:]]', (UTF8)s, U8'', NOCASE);
        ENDMACRO;

        LOCAL WithoutPunct(s) := FUNCTIONMACRO
            RETURN REGEXREPLACE(U8'[[:punct:]]', (UTF8)s, U8'', NOCASE);
        ENDMACRO;

        //-----------------------------------------------------
        // Collect top-level field names into a regex pattern
        //-----------------------------------------------------

        #UNIQUENAME(topLevelFieldPattern);
        #SET(topLevelFieldPattern, '');
        #UNIQUENAME(recLevel);
        #SET(recLevel, 0);
        #FOR(inFileFields)
            #FOR(Field)
                #IF(%{@isRecord}% = 1 OR %{@isDataset}% = 1)
                    #SET(recLevel, %recLevel% + 1)
                #ELSEIF(%{@isEnd}% = 1)
                    #SET(recLevel, %recLevel% - 1)
                #ELSEIF(%recLevel% = 0)
                    #IF(%'topLevelFieldPattern'% = '')
                        #APPEND(topLevelFieldPattern, '\\b(')
                    #ELSE
                        #APPEND(topLevelFieldPattern, '|')
                    #END
                    #APPEND(topLevelFieldPattern, %'{@name}'%)
                #END
            #END
        #END
        #IF(%'topLevelFieldPattern'% != '')
             #APPEND(topLevelFieldPattern, ')\\b')
        #END

        //-----------------------------------------------------
        // Define output record layout
        //-----------------------------------------------------

        #UNIQUENAME(validationRecName);
        #SET(validationRecName, (STRING)validationRecNameStr);

        #UNIQUENAME(OutRec);
        LOCAL %OutRec% := RECORD
            RECORDOF(inFile) - [%validationRecName%];
        END;

        //-----------------------------------------------------
        // Walk the supplied specStr
        //-----------------------------------------------------

        #UNIQUENAME(workingData);
        #UNIQUENAME(tempStr);
        #UNIQUENAME(pos);
        #UNIQUENAME(reasonConstraint);
        #UNIQUENAME(oneECLStmt);
        #UNIQUENAME(lhsECLTemp);
        #UNIQUENAME(lhsECL);
        #UNIQUENAME(rhsElse);
        #UNIQUENAME(rhsECL);
        #UNIQUENAME(field1);
        #UNIQUENAME(field2);

        #UNIQUENAME(trimmedSpecStr);
        #SET(trimmedSpecStr, TRIM((STRING)specStr, LEFT, RIGHT));

        #UNIQUENAME(operators);
        #SET(operators, '(AND|OR|NOT)');

        #UNIQUENAME(dataFilter);

        #SET(workingData, #TEXT(inFile));
        #SET(pos, 1);
        #LOOP
            #SET(dataFilter, '')
            #SET(oneECLStmt, '')
            #IF(%pos% < LENGTH(%'trimmedSpecStr'%))
            	#SET(tempStr, REGEXFIND('^([^;]+)', %'trimmedSpecStr'%[%pos%..], 1))
                #IF(%'tempStr'% != '')
                    #SET(reasonConstraint, TRIM(REGEXFIND('^([^:]+)', %'tempStr'%, 1), LEFT, RIGHT))
                    #IF(%'reasonConstraint'% != '')
                        // Modify logical operators so we cannot find them while parsing violation names
                        #SET(reasonConstraint, REGEXREPLACE('\\b' + %'operators'% + '\\b', %'reasonConstraint'%, '|$1|', NOCASE))
                        #SET(reasonConstraint, REGEXREPLACE('\\b([^\\|][\\w\\.\\-_]+[^\\|])\\b', %'reasonConstraint'%, '(\'$1\' IN LEFT.' + validationRecNameStr + '.violations)', NOCASE))
                        // Put logical operators back
                        #SET(reasonConstraint, REGEXREPLACE('(\\|' + %'operators'% + '\\|)', %'reasonConstraint'%, '$2', NOCASE))

                        // Extract the ECL for addressing the violations
                        #SET(oneECLStmt, TRIM(REGEXFIND(':(.+)', %'tempStr'%, 1), LEFT, RIGHT))
                        // Assume we have an ECL definition and parse LHS vs RHS
                        #SET(lhsECLTemp, REGEXFIND('^([\\w\\.\\-_]+) *:=', %'oneECLStmt'%, 1))
                        #SET(rhsECL, TRIM(REGEXFIND(':= *(.+)', %'oneECLStmt'%, 1), RIGHT))
                        #SET(rhsElse, REGEXREPLACE(%'topLevelFieldPattern'%, %'lhsECLTemp'%, 'LEFT.$1', NOCASE))

                        #IF(%'lhsECL'% != '' AND %'rhsECL'% != '')
                            // We do indeed have a definition; add SELF and LEFT
                            #SET(lhsECL, REGEXREPLACE(%'topLevelFieldPattern'%, %'lhsECLTemp'%, 'SELF.$1', NOCASE))
                            #SET(rhsECL, REGEXREPLACE(%'topLevelFieldPattern'%, %'rhsECL'%, 'LEFT.$1', NOCASE))
                            // Construct the TRANSFORM clause
                            #SET(oneECLStmt, %'lhsECL'% + ' := IF((' + %'reasonConstraint'% + '), (TYPEOF(' + %'lhsECL'% + '))(' + %'rhsECL'% + '), ' + %'rhsElse'% + ')')
                        #ELSEIF(REGEXFIND('Swap\\( *' + %'topLevelFieldPattern'% + ' *, *' + %'topLevelFieldPattern'% + '\\)', %'oneECLStmt'%, NOCASE))
                            // User wants to swap the values in two toplevel fields
                            #SET(field1, REGEXFIND('SWAP\\( *' + %'topLevelFieldPattern'% + ' *, *' + %'topLevelFieldPattern'% + '\\)', %'oneECLStmt'%, 1, NOCASE))
                            #SET(field2, REGEXFIND('SWAP\\( *' + %'topLevelFieldPattern'% + ' *, *' + %'topLevelFieldPattern'% + '\\)', %'oneECLStmt'%, 2, NOCASE))
                            #SET(oneECLStmt, 'SELF.' + %'field1'% + ' := IF((' + %'reasonConstraint'% + '), (TYPEOF(SELF.' + %'field1'% + '))LEFT.' + %'field2'% + ', LEFT.' + %'field1'% + ')')
                            #APPEND(oneECLStmt, ', SELF.' + %'field2'% + ' := IF((' + %'reasonConstraint'% + '), (TYPEOF(SELF.' + %'field2'% + '))LEFT.' + %'field1'% + ', LEFT.' + %'field2'% + ')')
                        #ELSEIF(REGEXFIND('^SkipRecord\\(\\)$', %'oneECLStmt'%, NOCASE))
                            // This should translate into a filter on the input data
                            #IF(%'dataFilter'% != '')
                                #APPEND(dataFilter, ' OR ')
                            #END
                            #APPEND(dataFilter, '(' + REGEXREPLACE('LEFT\\.', %'reasonConstraint'%, '') + ')')
                            #SET(oneECLStmt, '')
                        #ELSE
                            #ERROR('Unrecognized expression: "' + %'oneECLStmt'% + '"')
                        #END

                        #UNIQUENAME(newData)
                        LOCAL %newData% := PROJECT
                            (
                                %workingData%
                                #IF(%'dataFilter'% != '')
                                    (NOT(%dataFilter%))
                                #END,
                                TRANSFORM
                                    (
                                        RECORDOF(LEFT),
                                        #IF(%'oneECLStmt'% != '')
                                            %oneECLStmt%,
                                        #END
                                        SELF := LEFT
                                    )
                            );

                        #SET(workingData, %'newData'%)
                    #END
                #END
                #SET(pos, %pos% + LENGTH(%'tempStr'%) + 1)
            #ELSE
                #BREAK
            #END
        #END

        RETURN PROJECT(%workingData%, %OutRec%);
    ENDMACRO;

END;
