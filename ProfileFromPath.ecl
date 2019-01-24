/***
 * Function macro that allows you to profile a file knowing only its path.
 * The path is examined to determine its underlying type, record structure
 * and (if necessary) other metadata information needed in order to construct
 * a DATASET declaration for it.  The dataset is then passed to the Profile()
 * function macro for evaluation.
 *
 * For non-flat files, it is important that a record definition be available
 * in the file's metadata.  For just-sprayed files, this is commonly defined
 * in the first line of the file and furthermore that the "Record Structure
 * Present" option in the spray dialog box had been checked.
 *
 * All Profile() parameters are supported with the exception of fieldListStr.
 * The assumption here is that if you know about the fields in the file then
 * you probably have enough information to construct an accurate DATASET
 * declaration yourself and call Profile() directly.
 *
 * Note that this function requires HPCC Systems version 6.4.0 or later.  It
 * leverages the dynamic record lookup capabilities added to that version and
 * described in https://hpccsystems.com/blog/file-layout-resolution-compile-time.
 *
 * @param   path            The full path to the file to profile; REQUIRED
 * @param   maxPatterns     The maximum number of patterns (both popular and
 *                          rare) to return for each attribute; OPTIONAL,
 *                          defaults to 100
 * @param   maxPatternLen   The maximum length of a pattern; longer patterns
 *                          are truncated in the output; this value is also
 *                          used to set the maximum length of the data to
 *                          consider when finding cardinality and mode values;
 *                          must be 33 or larger; OPTIONAL, defaults to 100
 * @param   features        A comma-delimited string listing the profiling
 *                          elements to be included in the output; OPTIONAL,
 *                          defaults to a comma-delimited string containing all
 *                          of the available keywords:
 *                              KEYWORD                 AFFECTED OUTPUT
 *                              fill_rate               fill_rate
 *                                                      fill_count
 *                              cardinality             cardinality
 *                              cardinality_breakdown   cardinality_breakdown
 *                              best_ecl_types          best_attribute_type
 *                              modes                   modes
 *                              lengths                 min_length
 *                                                      max_length
 *                                                      ave_length
 *                              patterns                popular_patterns
 *                                                      rare_patterns
 *                              min_max                 numeric_min
 *                                                      numeric_max
 *                              mean                    numeric_mean
 *                              std_dev                 numeric_std_dev
 *                              quartiles               numeric_lower_quartile
 *                                                      numeric_median
 *                                                      numeric_upper_quartile
 *                              correlations            numeric_correlations
 *                          To omit the output associated with a single keyword,
 *                          set this argument to a comma-delimited string
 *                          containing all other keywords; note that the
 *                          is_numeric output will appear only if min_max,
 *                          mean, std_dev, quartiles, or correlations features
 *                          are active; also note that enabling the
 *                          cardinality_breakdown feature will also enable
 *                          the cardinality feature, even if it is not
 *                          explicitly enabled
 * @param   sampleSize      A positive integer representing a percentage of
 *                          inFile to examine, which is useful when analyzing a
 *                          very large dataset and only an estimated data
 *                          profile is sufficient; valid range for this
 *                          argument is 1-100; values outside of this range
 *                          will be clamped; OPTIONAL, defaults to 100 (which
 *                          indicates that the entire dataset will be analyzed)
 * @param   lcbLimit        A positive integer (<= 500) indicating the maximum
 *                          cardinality allowed for an attribute in order to
 *                          emit a breakdown of the attribute's values; this
 *                          parameter will be ignored if cardinality_breakdown
 *                          is not included in the features argument; OPTIONAL,
 *                          defaults to 64
 */
EXPORT ProfileFromPath(path,
                       maxPatterns = 100,
                       maxPatternLen = 100,
                       features = '\'fill_rate,best_ecl_types,cardinality,cardinality_breakdown,modes,lengths,patterns,min_max,mean,std_dev,quartiles,correlations\'',
                       sampleSize = 100,
                       lcbLimit = 64) := FUNCTIONMACRO
    IMPORT DataPatterns;
    IMPORT Std;

    // Function for gathering metadata associated with a file path
    LOCAL GetFileAttribute(STRING attr) := NOTHOR(Std.File.GetLogicalFileAttribute(path, attr));

    // Gather certain metadata about the given path
    LOCAL fileKind := GetFileAttribute('kind');
    LOCAL sep := GetFileAttribute('csvSeparate');
    LOCAL term := GetFileAttribute('csvTerminate');
    LOCAL quoteChar := GetFileAttribute('csvQuote');
    LOCAL escChar := GetFileAttribute('csvEscape');
    LOCAL headerLineCnt := GetFileAttribute('headerLength');

    // Dataset declaration for a delimited file
    LOCAL csvDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            CSV(HEADING(headerLineCnt), SEPARATOR(sep), TERMINATOR(term), QUOTE(quoteChar), ESCAPE(escChar))
        );

    // Dataset declaration for a flat file
    LOCAL flatDataset := DATASET
        (
            path,
            RECORDOF(path, LOOKUP),
            FLAT
        );

    // Function macro to properly scope execution of Profile()
    LOCAL RunProfile(tempFile, _maxPatterns, _maxPatternLen, _features, _sampleSize, _lcb) := FUNCTIONMACRO
        RETURN DataPatterns.Profile
            (
                tempFile,
                maxPatterns := _maxPatterns,
                maxPatternLen := _maxPatternLen,
                features := _features,
                sampleSize := _sampleSize,
                lcbLimit := _lcb
            );
    ENDMACRO;

    // The returned value needs to be in a common format; dynamically determine
    // the record structure of the Profile result so it can be used to coerce
    // the individual Profile calls (and to provide an empty dataset in case
    // of an error)
    LOCAL CommonResultRec := RECORDOF
        (
            RunProfile(DATASET([], {STRING s}), maxPatterns, maxPatternLen, features, sampleSize, lcbLimit)
        );

    // This is really a do-nothing routine, as the results of the RunProfile()
    // call will be in the appropriate format, but doing it this way keeps
    // the ECL compiler happy
    LOCAL RunProfileAndCoerce(tempFile, _maxPatterns, _maxPatternLen, _features, _sampleSize, _lcb) := FUNCTIONMACRO
        LOCAL theProfile := RunProfile(tempFile, _maxPatterns, _maxPatternLen, _features, _sampleSize, _lcb);

        RETURN PROJECT
            (
                theProfile,
                TRANSFORM
                    (
                        CommonResultRec,
                        SELF := LEFT
                    )
            );
    ENDMACRO;

    LOCAL resultProfile := CASE
        (
            fileKind,
            'flat'  =>  RunProfileAndCoerce(flatDataset, maxPatterns, maxPatternLen, features, sampleSize, lcbLimit),
            'csv'   =>  RunProfileAndCoerce(csvDataset, maxPatterns, maxPatternLen, features, sampleSize, lcbLimit),
            ERROR(DATASET([], CommonResultRec), 'Cannot run Profile on file of kind "' + fileKind + '"')
        );

    RETURN resultProfile;
ENDMACRO;
