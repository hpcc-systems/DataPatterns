### DataPatterns

DataPatterns is an ECL bundle that provides some basic data profiling and
research tools to an ECL programmer.

### Installation

This code is installed as an ECL Bundle.  Complete instructions for managing ECL
Bundles can be found in [The ECL IDE and HPCC Client
Tools](http://cdn.hpccsystems.com/releases/CE-Candidate-6.2.0/docs/TheECLIDEandHPCCClientTools-6.2.0-1.pdf) documentation.

Use the ecl command line tool to install this bundle:

    ecl bundle install https://github.com/hpcc-systems/DataPatterns.git

You may have to either navigate to the client tools bin directory before
executing the command, or use the full path to the ecl tool.

After installation, all of the code here becomes available after you import it:

    IMPORT DataPatterns;

Note that is possible to use this code without installing it as a bundle.  To do
so, simply make it available within your IDE and just ignore the Bundle.ecl
file. With the Windows IDE, the DataPatterns directory must not be a top-level
item in your repository list; it needs to be installed one level below the top
level, such as within your "My Files" folder.

### Release Notes

|Version|Notes|
|:----:|:-----|
|1.0.0|Initial public release, finally with support for datasets defined using dynamic record lookup|
|1.0.1|Add `ProfileFromPath` and `BestRecordStructureFromPath`; ave\_length bug fix|


### Profile

Documentation as pulled from the beginning of Profile.ecl:

    Profile() is a function macro for profiling all or part of a dataset.
    The output is a dataset containing the following information for each
    profiled attribute:

         attribute               The name of the attribute
         given_attribute_type    The ECL type of the attribute as it was defined
                                 in the input dataset
         best_attribute_type     An ECL data type that both allows all values
                                 in the input dataset and consumes the least
                                 amount of memory
         rec_count               The number of records analyzed in the dataset;
                                 this may be fewer than the total number of
                                 records, if the optional sampleSize argument
                                 was provided with a value less than 100
         fill_count              The number of rec_count records containing
                                 non-nil values
         fill_rate               The percentage of rec_count records containing
                                 non-nil values; a 'nil value' is an empty
                                 string or a numeric zero; note that BOOLEAN
                                 attributes are always counted as filled,
                                 regardless of their value; also, fixed-length
                                 DATA attributes (e.g. DATA10) are also counted
                                 as filled, given their typical function of
                                 holding data blobs
         cardinality             The number of unique, non-nil values within
                                 the attribute
         modes                   The most common values in the attribute, after
                                 coercing all values to STRING, along with the
                                 number of records in which the values were
                                 found; if no value is repeated more than once
                                 then no mode will be shown; up to five (5)
                                 modes will be shown; note that string values
                                 longer than the maxPatternLen argument will
                                 be truncated
         min_length              The shortest length of a value when expressed
                                 as a string; null values are ignored
         max_length              The longest length of a value when expressed
                                 as a string
         ave_length              The average length of a value when expressed
                                 as a string
         popular_patterns        The most common patterns of values; see below
         rare_patterns           The least common patterns of values; see below
         is_numeric              Boolean indicating if the original attribute
                                 was numeric and therefore whether or not
                                 the numeric_xxxx output fields will be
                                 populated with actual values; if this value
                                 is FALSE then all numeric_xxxx output values
                                 should be ignored
         numeric_min             The smallest non-nil value found within the
                                 attribute as a DECIMAL; the attribute must be
                                 a numeric ECL datatype; non-numeric attributes
                                 will return zero
         numeric_max             The largest non-nil value found within the
                                 attribute as a DECIMAL; the attribute must be
                                 a numeric ECL datatype; non-numeric attributes
                                 will return zero
         numeric_mean            The mean (average) non-nil value found within
                                 the attribute as a DECIMAL; the attribute must
                                 be a numeric ECL datatype; non-numeric
                                 attributes will return zero
         numeric_std_dev         The standard deviation of the non-nil values
                                 in the attribute as a DECIMAL; the attribute
                                 must be a numeric ECL datatype; non-numeric
                                 attributes will return zero
         numeric_lower_quartile  The value separating the first (bottom) and
                                 second quarters of non-nil values within
                                 the attribute as a DECIMAL; the attribute must
                                 be a numeric ECL datatype; non-numeric
                                 attributes will return zero
         numeric_median          The median non-nil value within the attribute
                                 as a DECIMAL; the attribute must be a numeric
                                 ECL datatype; non-numeric attributes will return
                                 zero
         numeric_upper_quartile  The value separating the third and fourth
                                 (top) quarters of non-nil values within
                                 the attribute as a DECIMAL; the attribute must
                                 be a numeric ECL datatype; non-numeric
                                 attributes will return zero
         numeric_correlations    A child dataset containing correlation values
                                 comparing the current numeric attribute with all
                                 other numeric attributes, listed in descending
                                 correlation value order; the attribute must be
                                 a numeric ECL datatype; non-numeric attributes
                                 will return an empty child dataset; note that
                                 this can be a time-consuming operation,
                                 depending on the number of numeric attributes
                                 in your dataset and the number of rows (if you
                                 have N numeric attributes, then
                                 N * (N - 1) / 2 calculations are performed,
                                 each scanning all data rows)

    Most profile outputs can be disabled.  See the 'features' argument, below.

    Data patterns can give you an idea of what your data looks like when it is
    expressed as a (human-readable) string.  The function converts each
    character of the string into a fixed character palette to produce a "data
    pattern" and then counts the number of unique patterns for that attribute.
    The most- and least-popular patterns from the data will be shown in the
    output, along with the number of times that pattern appears and an example
    (randomly chosen from the actual data).  The character palette used is:

         A   Any uppercase letter
         a   Any lowercase letter
         9   Any numeric digit
         B   A boolean value (true or false)

    All other characters are left as-is in the pattern.

    Only the top level attributes within a dataset are processed; embedded
    records and child recordsets are skipped.  SET data types (such as
    SET OF INTEGER) are also skipped.  If the dataset contains only
    embedded records and/or child recordsets, or if fieldListStr is specified
    but with attributes that don't actually exist in the top level (or are
    invalid) then an error will be produced during compilation time.

    This function works best when the incoming dataset contains attributes that
    have precise data types (e.g. UNSIGNED4 data types instead of numbers
    stored in a STRING data type).

    Function parameters:

    @param   inFile          The dataset to process; REQUIRED
    @param   fieldListStr    A string containing a comma-delimited list of
                             attribute names to process; use an empty string to
                             process all attributes in inFile; attributes named
                             here that are not found in the top level of inFile
                             will be ignored; OPTIONAL, defaults to an
                             empty string
    @param   maxPatterns     The maximum number of patterns (both popular and
                             rare) to return for each attribute; OPTIONAL,
                             defaults to 100
    @param   maxPatternLen   The maximum length of a pattern; longer patterns
                             are truncated in the output; this value is also
                             used to set the maximum length of the data to
                             consider when finding cardinality and mode values;
                             must be 33 or larger; OPTIONAL, defaults to 100
    @param   features        A comma-delimited string listing the profiling
                             elements to be included in the output; OPTIONAL,
                             defaults to a comma-delimited string containing all
                             of the available keywords:
                                 KEYWORD         AFFECTED OUTPUT
                                 fill_rate       fill_rate
                                                 fill_count
                                 cardinality     cardinality
                                 best_ecl_types  best_attribute_type
                                 modes           modes
                                 lengths         min_length
                                                 max_length
                                                 ave_length
                                 patterns        popular_patterns
                                                 rare_patterns
                                 min_max         numeric_min
                                                 numeric_max
                                 mean            numeric_mean
                                 std_dev         numeric_std_dev
                                 quartiles       numeric_lower_quartile
                                                 numeric_median
                                                 numeric_upper_quartile
                                 correlations    numeric_correlations
                             To omit the output associated with a single keyword,
                             set this argument to a comma-delimited string
                             containing all other keywords; note that the
                             is_numeric output will appear only if min_max,
                             mean, std_dev, quartiles, or correlations features
                             are active
    @param   sampleSize      A positive integer representing a percentage of
                             inFile to examine, which is useful when analyzing a
                             very large dataset and only an estimated data
                             profile is sufficient; valid range for this
                             argument is 1-100; values outside of this range
                             will be clamped; OPTIONAL, defaults to 100 (which
                             indicates that the entire dataset will be analyzed)

Here is a very simple example of executing the full data profiling code:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

    profileResults := DataPatterns.Profile(ds);

    OUTPUT(profileResults, ALL, NAMED('profileResults'));

### ProfileFromPath

You can also profile a logical file by knowing only its path:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    profileResults := DataPatterns.ProfileFromPath(filePath);

    OUTPUT(profileResults, ALL, NAMED('profileResults'));

`ProfileFromPath` accepts the same arguments as `Profile`, with the exception
of `fieldListStr` (the assumption is, if you know the fields then you know
enough to construct a dataset and can use `Profile` instead).

### BestRecordStructure

This is a function macro that, given a dataset, returns a recordset containing
the "best" record definition for the given dataset.  By default, the entire
dataset will be examined. You can override this behavior by providing a
percentage of the dataset to examine (1-100) as the second argument.  This is
useful if you are checking a very large file and are confident that a sample
will provide correct results.

There is an important limitation in this function:  Child datasets and embedded
record definitions are ignored entirely (this comes from the fact that this
function calls the Profile() function, and that function ignores child datasets
and embedded records).  All other top-level attributes are returned, though, so
you can edit the returned string and insert anything that is missing.

Sample call:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);

    recordDefinition := DataPatterns.BestRecordStructure(ds);

    OUTPUT(recordDefinition, NAMED('recordDefinition'), ALL);

The result will be a recordset containing only a STRING field.  The first
record will always contain 'RECORD' and the last record will always contain
'END;'.  The records in between will contain declarations for the attributes
found within the given dataset.  The entire result can be copied and pasted
into an ECL code module.

Note that, when outputing the result of `BestRecordStructure` to a workunit,
it is a good idea to add an ALL flag to the OUTPUT function.  This ensures that
all attributes will be displayed.  Otherwise, if you have more than 100
attributes in the given dataset, the result will be truncated.

### BestRecordStructureFromPath

Similar to `ProfileFromPath`, you can obtain the best ECL record structure for
a logical file given only its path:

    IMPORT DataPatterns;

    filePath := '~thor::my_sample_data';

    recordDefinition := DataPatterns.BestRecordStructureFromPath(filePath);

    OUTPUT(recordDefinition, NAMED('recordDefinition'), ALL);

`BestRecordStructureFromPath` accepts the same arguments as
`BestRecordStructure`.

### Testing

The data profiling code can be easily tested with the included Tests module.
hthor or ROXIE should be used to execute the tests, simply because Thor takes a
relatively long time to execute them.  Here is how you invoke the tests:

    IMPORT DataPatterns;

    EVALUATE(DataPatterns.Tests);

If the tests pass then the execution will succeed and there will be no output.
These tests may take some time to execute on Thor.  They run much faster on
either hthor or ROXIE, due to the use of small inline datasets.
