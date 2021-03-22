### DataPatterns

DataPatterns is an ECL bundle that provides some basic data profiling and
research tools to an ECL programmer.

### Table of Contents

  * [Installation](#installation)
  * [Release Notes](#release_notes)
  * [Profile()](#profile)
    * [Summary Report with Graphs](#summary_report_with_graphs)
  * [NormalizeProfileResults()](#normalizeprofileresults)
  * [BestRecordStructure()](#bestrecordstructure)
  * [Data Validation Submodule](#validation)
    * [Validate()](#validation_validate)
    * [Fix()](#validation_fix)
  * [Benford()](#benford)
  * [Profile() Testing](#testing)

<a name="installation"></a>
### Installation

**Note:**  `DataPatterns.Profile()` and `DataPatterns.BestRecordStructure()` are
now included in HPCC version 7.4.0!  They have been added to the ECL Standard
Library (within `Std.DataPatterns`) and also integrated with ECL Watch so you can
create a profile from a saved logical file using only a web browser.  Note that
the Std library version of Profile() will create a visualization of the results
only when executed from ECL Watch; visualizations will not be generated if
Profile() is called from ECL code.  If that is important to you, install this
bundle version instead (they coexist peacefully).

This code is installed as an ECL Bundle.  Complete instructions for managing ECL
Bundles can be found in [The ECL IDE and HPCC Client
Tools](https://cdn.hpccsystems.com/releases/CE-Candidate-7.12.0/docs/EN_US/TheECLIDEandHPCCClientTools_EN_US-7.12.0-1.pdf)
documentation.

Use the ecl command line tool to install this bundle:

    ecl bundle install https://github.com/hpcc-systems/DataPatterns.git

You may have to either navigate to the client tools bin directory before
executing the command, or use the full path to the ecl tool.

After installation, all of the code here becomes available after you import it:

```ECL
IMPORT DataPatterns;
```

Note that is possible to use this code without installing it as a bundle.  To do
so, simply make it available within your IDE and just ignore the Bundle.ecl
file. With the Windows IDE, the DataPatterns directory must not be a top-level
item in your repository list; it needs to be installed one level below the top
level, such as within your "My Files" folder.

<a name="release_notes"></a>
### Release Notes
<details>
<summary>Click to expand</summary>

|Version|Notes|
|:----:|:-----|
|1.0.0|Initial public release, finally with support for datasets defined using dynamic record lookup|
|1.0.1|Add `ProfileFromPath` and `BestRecordStructureFromPath`; ave\_length bug fix|
|1.0.2|Change attribute field in CorrelationsRec embedded dataset to STRING|
|1.1.0|Add record count breakdown for low-cardinality field values; ProfileFromPath() returns correct record structure|
|1.1.1|Examine UTF8 values for alternate best\_attribute\_type data types rather than just passing them through|
|1.2.0|Add option to emit a suitable TRANSFORM function to BestRecordStructure and BestRecordStructureFromPath|
|1.2.1|Just-sprayed CSV files now supported within BestRecordStructureFromPath|
|1.2.2|Bug fix: Support datasets that contain reserved words as field names (e.g. loop)|
|1.3.0|Support for embedded child records; bug fix for proper computing of upper quartile value|
|1.3.1|Just-sprayed CSV files now supported within ProfileFromPath|
|1.3.2|Allow most CSV attributes to acquire default values in ProfileFromPath and BestRecordStructureFromPath|
|1.3.3|Add file kind gathering back to the code in ProfileFromPath and BestRecordStructureFromPath (regression from 1.3.2)|
|1.3.4|When given explicit numeric attribute types, refrain from recommending a "best" attribute type|
|1.3.5|Fix ordering of output in BestRecordStructure when TRANSFORM is emitted|
|1.4.0|Automatically include improved visual results of Profile, including data distribution graphs (within workunit's Resources tab)|
|1.4.1|Regression: Fix self-tests that were failing due to changes in v1.3.4|
|1.4.2|String fields containing all numerics with leading zeros are now marked as string in best\_attribute\_type; string fields where the length varies by more than three orders of magnitude are now marked as string in best\_attribute\_type|
|1.5.0|Add support for SET OF data types and child datasets|
|1.5.1|Support for tabbed visual results of multiple profiles in a workunit's result; changes to avoid symbol collision in calling ECL code; visual report styling update|
|1.5.2|Import the ECL Standard Library within the Profile() function macro so callers do not have to|
|1.5.3|Fix leading-zero numeric test, ensuring that only all-numeric values are considered as string type candidates|
|1.5.4|Fix tab issues that appeared when multiple profiling results were available|
|1.5.5|Fix visualized report vertical scrolling problems; update dependency to resolve security issue; removed erroneous HTML fragment from reports|
|1.5.7|Add NormalizeProfileResults() function macro (see below for details); fix ECL compiler problem accessing child datasets hosted within embedded child records; make sure empty child dataset information appears in the final output|
|1.6.0|is\_numeric result is now based upon best\_attribute\_type rather than given\_attribute\_type, and the numeric\_xxxx results will appear for those attributes as well; renamed numeric\_correlations result to simply correlations||
|1.6.1|Fix problem where large datasets with implicit numeric conversions ran out of memory during the final phase of profiling|
|1.6.2|Fix issue where a record definition END would appear in the wrong place within BestRecordStructure(); remove BestRecordStructureFromPath() and ProfileFromPath() -- they never worked in all circumstances|
|1.6.3|Fix issue where fields in the NewLayout record definition emitted by BestRecordStructure were out of order|
|1.6.4|Bump visualizer code, including dependencies, to latest versions; increase default lcbLimit value to 1000|
|1.6.5|Significant (~75%) performance boost within the text pattern code  -- thanks to Manjunath Venkataswamy for finding the issue|
|1.7.0|NormalizeProfileResults() now shows results for attributes within child datasets (text patterns, correlations, etc); addition of Benford() analysis function; add workaround to allow a child dataset to be cited in a fieldListStr argument in Profile()|
|1.7.1|Fix digit selection code in Benford|
|1.7.2|Benford: Recognize implied trailing zeros after a decimal point|
|1.8.0|Addition of Validation module; minor optimization in text pattern generation|
|1.8.1|Fix issue with correlation with a numeric field named 'row'|
|1.8.2|Security: Bump Viz Versions|
|1.9.0|New functionality:  Cardinality() function|
</details>

---
<a name="profile"></a>
### Profile

Documentation as pulled from the beginning of [Profile.ecl](Profile.ecl):

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
                                 non-nil values; a 'nil value' is an empty
                                 string, a numeric zero, or an empty SET; note
                                 that BOOLEAN attributes are always counted as
                                 filled, regardless of their value; also,
                                 fixed-length DATA attributes (e.g. DATA10) are
                                 also counted as filled, given their typical
                                 function of holding data blobs
         fill_rate               The percentage of rec_count records containing
                                 non-nil values; this is basically
                                 fill_count / rec_count * 100
         cardinality             The number of unique, non-nil values within
                                 the attribute
         cardinality_breakdown   For those attributes with a low number of
                                 unique, non-nil values, show each value and the
                                 number of records containing that value; the
                                 lcbLimit parameter governs what "low number"
                                 means
         modes                   The most common values in the attribute, after
                                 coercing all values to STRING, along with the
                                 number of records in which the values were
                                 found; if no value is repeated more than once
                                 then no mode will be shown; up to five (5)
                                 modes will be shown; note that string values
                                 longer than the maxPatternLen argument will
                                 be truncated
         min_length              For SET datatypes, the fewest number of elements
                                 found in the set; for other data types, the
                                 shortest length of a value when expressed
                                 as a string; null values are ignored
         max_length              For SET datatypes, the largest number of elements
                                 found in the set; for other data types, the
                                 longest length of a value when expressed
                                 as a string; null values are ignored
         ave_length              For SET datatypes, the average number of elements
                                 found in the set; for other data types, the
                                 average length of a value when expressed
         popular_patterns        The most common patterns of values; see below
         rare_patterns           The least common patterns of values; see below
         is_numeric              Boolean indicating if the original attribute
                                 was a numeric scalar or if the best_attribute_type
                                 value was a numeric scaler; if TRUE then the
                                 numeric_xxxx output fields will be
                                 populated with actual values; if this value
                                 is FALSE then all numeric_xxxx output values
                                 should be ignored
         numeric_min             The smallest non-nil value found within the
                                 attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_max             The largest non-nil value found within the
                                 attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_mean            The mean (average) non-nil value found within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_std_dev         The standard deviation of the non-nil values
                                 in the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_lower_quartile  The value separating the first (bottom) and
                                 second quarters of non-nil values within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_median          The median non-nil value within the attribute
                                 as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         numeric_upper_quartile  The value separating the third and fourth
                                 (top) quarters of non-nil values within
                                 the attribute as a DECIMAL; this value is valid only
                                 if is_numeric is TRUE; if is_numeric is FALSE
                                 then zero will show here
         correlations            A child dataset containing correlation values
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

    Function parameters:

    @param   inFile          The dataset to process; this could be a child
                             dataset (e.g. inFile.childDS); REQUIRED
    @param   fieldListStr    A string containing a comma-delimited list of
                             attribute names to process; use an empty string to
                             process all attributes in inFile; OPTIONAL,
                             defaults to an empty string
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
                                 KEYWORD                 AFFECTED OUTPUT
                                 fill_rate               fill_rate
                                                         fill_count
                                 cardinality             cardinality
                                 cardinality_breakdown   cardinality_breakdown
                                 best_ecl_types          best_attribute_type
                                 modes                   modes
                                 lengths                 min_length
                                                         max_length
                                                         ave_length
                                 patterns                popular_patterns
                                                         rare_patterns
                                 min_max                 numeric_min
                                                         numeric_max
                                 mean                    numeric_mean
                                 std_dev                 numeric_std_dev
                                 quartiles               numeric_lower_quartile
                                                         numeric_median
                                                         numeric_upper_quartile
                                 correlations            correlations
                             To omit the output associated with a single keyword,
                             set this argument to a comma-delimited string
                             containing all other keywords; note that the
                             is_numeric output will appear only if min_max,
                             mean, std_dev, quartiles, or correlations features
                             are active; also note that enabling the
                             cardinality_breakdown feature will also enable
                             the cardinality feature, even if it is not
                             explicitly enabled
    @param   sampleSize      A positive integer representing a percentage of
                             inFile to examine, which is useful when analyzing a
                             very large dataset and only an estimated data
                             profile is sufficient; valid range for this
                             argument is 1-100; values outside of this range
                             will be clamped; OPTIONAL, defaults to 100 (which
                             indicates that the entire dataset will be analyzed)
    @param   lcbLimit        A positive integer (<= 1000) indicating the maximum
                             cardinality allowed for an attribute in order to
                             emit a breakdown of the attribute's values; this
                             parameter will be ignored if cardinality_breakdown
                             is not included in the features argument; OPTIONAL,
                             defaults to 64

Here is a very simple example of executing the full data profiling code:

```ECL
IMPORT DataPatterns;

filePath := '~thor::my_sample_data';
ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);
profileResults := DataPatterns.Profile(ds);
OUTPUT(profileResults, ALL, NAMED('profileResults'));
```

<a name="summary_report_with_graphs"></a>
### Profile(): Summary Report with Graphs

A report is generated based on the output of `Profile()`. The report is
accessible via a Workunit's *Resources* tab within ECL Watch. For example:

![Screen capture displaying active Resources tab](https://user-images.githubusercontent.com/1891935/57020403-2ac29480-6bf7-11e9-9584-a6fd23a3b4c4.png)

Every `attribute` in the Profile result is represented by a row of information.
Each row of information is organized into several columns. Here is a short description
of each column:

1. Type information, Cardinality Count & Filled Count
2. Min, Avg, Max Length (for string attributes) or Mean, Std. Deviation, Quartiles (for numeric attributes)
3. Quartile bell curve and candlestick
    * only shown for attributes with `is_numeric` === `true`
    * this column is omitted if the above condition fails for all attributes
4. Cardinality Breakdown listed by count descending
    * only shown for attributes with `cardinality_breakdown` content
    * this column is omitted if the above condition fails for all attributes
5. Popular Patterns
    * only shown for attributes with `popular_patterns` content
    * this column is omitted if the above condition fails for all attributes

This is a screen capture displaying a report row for a string attribute
("Test\_Name") and a numeric attribute ("Test\_Score"):

![Screen capture of two report rows](https://user-images.githubusercontent.com/1891935/56989566-c228d880-6b60-11e9-87a8-c2aa1c76b3d8.png)

---
<a name="normalizeprofileresults"></a>
### NormalizeProfileResults

The result of a call to `Profile` is a rich dataset.
There are several fields (depending on the features requested) and some
of them can include child datasets embedded for each field from the dataset
being profiled.

In some circumstances, it would be advantageous to save the profile results
in a more normalized format.  For instance, a normalized format would allow
the task of comparing one profile result to another to be much easier.

`NormalizeProfileResults` accepts only one argument:  the dataset representing
the result of a call to either `Profile`.  The result
is a dataset in the following format:

    RECORD
        STRING      attribute;  // Field from profiled dataset
        STRING      key;        // Field from profile results
        STRING      value;      // Value from profile results
    END;

Some profile results are represented with embedded child datasets (modes,
cardinality breakdowns, text patterns, and correlations).  When normalizing,
portions of these child datasets are converted to string values delimited
by the '&#124;' character.  If records within the child dataset contain
additional information, such as a record count, the additional information
is delimited with a ':' character.

Sample code:

```ECL
IMPORT DataPatterns;

filePath := '~thor::my_sample_data';
ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);
profileResults := DataPatterns.Profile(ds);
normalizedResults := DataPatterns.NormalizeProfileResults(profileResults);
OUTPUT(normalizedResults, ALL, NAMED('normalizedResults'));
```

profileResults:

|attribute|given\_attribute\_type|rec\_count|fill\_count|fill\_rate|popular_patterns|
|---|---|---|---|---|---|
|field1|string|1000|1000|100|<table><tr><th>data\_patterns</th><th>rec_count</th></tr><tr><td>AAAAAA</td><td>10</td></tr><tr><td>AAA</td><td>5</td></tr></table>

normalizedResults:

|attribute|key|value|
|---|---|---|
|field1|given\_attribute\_type|string|
|field1|rec\_count|1000|
|field1|fill\_count|1000|
|field1|fill\_rate|100|
|field1|popular_patterns|AAAAAA:10&#124;AAA:5|

---
<a name="bestrecordstructure"></a>
### BestRecordStructure

This is a function macro that, given a dataset, returns a recordset containing
the "best" record definition for the given dataset.  By default, the entire
dataset will be examined. You can override this behavior by providing a
percentage of the dataset to examine (1-100) as the second argument.  This is
useful if you are checking a very large file and are confident that a sample
will provide correct results.

Sample call:

```ECL
IMPORT DataPatterns;

filePath := '~thor::my_sample_data';
ds := DATASET(filePath, RECORDOF(filePath, LOOKUP), FLAT);
recordDefinition := DataPatterns.BestRecordStructure(ds);
OUTPUT(recordDefinition, NAMED('recordDefinition'), ALL);
```

The result will be a recordset containing only a STRING field.  The first
record will always contain 'RECORD' and the last record will always contain
'END;'.  The records in between will contain declarations for the attributes
found within the given dataset.  The entire result can be copied and pasted
into an ECL code module.

Note that, when outputing the result of `BestRecordStructure` to a workunit,
it is a good idea to add an ALL flag to the OUTPUT function.  This ensures that
all attributes will be displayed.  Otherwise, if you have more than 100
attributes in the given dataset, the result will be truncated.

---
<a name="validation"></a>
### Data Validation Submodule

Validation exists as a submodule within DataPatterns.  It contains two function
macros:  `Validate()` and `Fix()`.

`Validate()` provides an easy mechanism for testing expected field values at
the record level, then append those test results to each record in a
standardized layout.  Tests are named, and associated with each test is
a bit of ECL that defines what a valid field should look like.  Fields with
values that do not pass that test are flagged.

`Fix()` is the other half of the testing:  Once you have the output from
`Validate()` you will need to handle the failing field values somehow.  The
`Fix()` function macro processes records with failures and gives you the
opportunity to correct the error or to omit the record entirely.

<a name="validation_validate"></a>
#### Validation.Validate()

Documentation as pulled from [Validation.ecl](Validation.ecl):

Validation checks are defined within a semicolon-delimited STRING.  Each check
should be in the following format:

     <test_name>:<test_ecl>

`test_name` should be a name somehow representing the check that is
being performed.  The name will be included in the appended data if the
check fails.  This name should clearly (but succinctly) describe what is
being tested.  There is no requirement for a `test_name` to be unique
(and there some use cases where you may not want it unique at all) but,
in general, the name should be unique within a single `Validate()` call.
Names should start with a letter and may contain letters, numbers, periods,
dashes, and underscores.

`test_ecl` is ECL code that performs the test.  If a string literal is
included in the test then the apostrophes must be escaped because the test
is being defined within a string.  If a `REGEXFIND()` or `REGEXREPLACE()`
function is used and anything within the pattern needs to be escaped then
the backslash must be double-escaped.  ECL already requires a single escape
(`\\.` or `\\d`) but including it in a test here means you have to
double-escape the backslash: `\\\\.` or `\\\\d`.

The ECL code used during the test is executed within the scope of a single
dataset record.  Syntax-wise, it is similar to creating an ECL filter clause.
Like a filter, the ECL should evaluate to a `BOOLEAN` result and what you want
to do is return `TRUE` if the data being tested is **valid**.  Invalid results,
where the ECL returns `FALSE`, are what is appended to the dataset.

`Validate()` imports the Std ECL library, so all standard library functions
are available for use within a test.  Also, because `Validate()` is a function
macro, any function that is in scope when `Validate()` is called may also be
used within a test.  This provides quite a bit of flexibility when it comes
to writing tests.  The example code below references `StartsWithAA()` which
is an example of one of these user-supplied tests.

`Validate()` also includes a few internally-defined functions for use within
your tests as a convenience.  Some are coercion functions that alter a field's
value, others are test functions.  These tests are not available for use in
your own custom, externally-defined tests.

Coercion helpers:

    OnlyDigits(s)       Convert a single argument to a string and remove
                        everything but numeric digits; returns a STRING

    OnlyChars(s)        Convert a single argument to a UTF-8 string and remove
                        everything but alphabetic characters; returns a
                        UTF8 string

    WithoutPunct(s)     Convert a single argument to a UTF-8 string and remove
                        all punctuation characters; returns a UTF8 string

    Patternize(s)       Create a 'text pattern' from the single argument,
                        mapping character classes to a fixed palette:
                            lowercase character -> a
                            uppercase character -> A
                            numeric digit       -> 9
                            everything else     -> unchanged
                        The result is returned as a UTF8 string

Value testing helpers:

    StrLen(s)           Convert a single argument to a UTF-8 string and return
                        its length as an unsigned integer

    IsOnlyDigits(s)     Return TRUE if every character in the value is a digit

    IsOnlyUppercase(s)  Return TRUE if every character in the value is an
                        uppercase character

    IsOnlyLowercase(s)  Return TRUE if every character in the value is a
                        lowercase character

    IsDecimalNumber(s)  Return TRUE if the value is a number, possibly prefixed
                        by a negative sign, and possibly including a decimal
                        portion

Record-level testing helpers:

    AllFieldsFilled()   Tests every top-level field in the record by coercing
                        the values to STRING and seeing if any of them are empty;
                        returns TRUE if no field value is an empty string; note
                        that this function accepts no argument

Example test specifications:

     MyValueIsPos:my_value > 0 // my_value must be greater than zero
     SomeNumInRange:some_num BETWEEN 50 AND 100 // some_num must be 50..100
     FIPSLength:StrLen(fips) = 5 // length of FIPS code must be 5
     DatesOrdered:dateBegin <= dateEnd // make sure dates are not flipped

Here is a complete example:

```ECL
IMPORT DataPatterns;

filePath := '~thor::stock_data.txt';

DataRec := RECORD
    STRING  trade_date;
    STRING  exchange_code;
    STRING  stock_symbol;
    STRING  opening_price;
    STRING  high_price;
    STRING  low_price;
    STRING  closing_price;
    STRING  shares_traded;
    STRING  share_value;
END;

ds := DATASET(filePath, DataRec, CSV(SEPARATOR('\t'), HEADING(1)));

// Custom, external field validation functions
StartsWithAA(STRING s) := s[1..2] = 'AA';
IsValidPrice(STRING price) := NOT(REGEXFIND('^\\d+?00$', price) AND (UNSIGNED)price >= 10000);

checks := 'NonZeroLowPrice:(REAL)low_price > 0'
            + '; NonZeroHighPrice:(REAL)high_price > 0'
            + '; LowPriceLessOrEqualToHighPrice:(REAL)low_price <= (REAL)high_price'
            + '; OpeningPriceGreaterThanOne:(REAL)opening_price > 1'
            + '; OpeningPriceFormat:REGEXFIND(U8\'9+(\\\\.9{1,2})?\', Patternize(opening_price))'
            + '; OpeningPriceValid:IsValidPrice(opening_price)'
            + '; ClosingPriceValid:IsValidPrice(closing_price)'
            + '; SymbolStartsWithAA:StartsWithAA(stock_symbol)'
            + '; EveryFieldPresent:AllFieldsFilled()'
            ;

validationResult := DataPatterns.Validation.Validate(ds, specStr := checks);
OUTPUT(validationResult, {validationResult}, '~thor::stock_data_validated', OVERWRITE, COMPRESSED);
```
<a name="validation_fix"></a>
#### Validation.Fix()

Fixes are defined within a semicolon-delimited STRING.  Each fix should
be in the following format:

     <membership_test>:<fix_ecl>

`membership_test` is a logical clause testing whether one or more tests
from the `Validate()` function is true for that record.  The entries here
correspond to the `test_name` entries from the `Validate()` function and
they can optionally form a boolean expression using AND and OR operators.
At its simplest, a `membership_test` is just a single `test_name` entry and
it will be interpreted as the following ECL:

     ('test_name' IN vaidation_results.violations)

More complex boolean expressions will use that as the basis.  For instance,
testing for "`test_name_1` OR `test_name_2`" -- meaning, if either of the two
validation checks failed, execute the `fix_ecl` code -- would be interpreted as the
following ECL:

      (('test_name_1' IN vaidation_results.violations)
       OR
       ('test_name_2' IN vaidation_results.violations))

The NOT() operator is also available, so testing for the absence of a
validation is supported.

`fix_ecl` is ECL code that fixes the problem.  The most basic fix is
redefining a field value (e.g. `my_field := new_value_expression`).
If a string literal is included in the fix then the apostrophes must be
escaped because it is being defined within a string.  If a `REGEXFIND()`
or `REGEXREPLACE()` function is used and anything within the pattern needs
to be escaped then the backslash must be double-escaped.  ECL already
requires a single escape (`\\.` or `\\d`) but including it in a test here
means you have to double-escape the backslash: `\\\\.` or `\\\\d`.

The ECL code used during the fix is executed within the scope of a single
dataset record.  This means that the expression may reference any field
in the record.  There is no need to include SELF or LEFT scoping prefixes
when citing a dataset field name.

`Fix()` imports the Std ECL library, so all standard library functions
are available for use within a fix.  Also, because `Fix()` is a function
macro, any function that is in scope when `Fix()` is called may also be
used within a fix.

`Fix()` also includes a few internally-defined functions for use within
your fixes as a convenience:

     OnlyDigits(s)       Convert a single argument to a UTF-8 string and remove
                         everything but numeric digits

     OnlyChars(s)        Convert a single argument to a UTF-8 string and remove
                         everything but alphabetic characters

     WithoutPunct(s)     Convert a single argument to a UTF-8 string and remove
                         all punctuation characters

     Swap(f1, f2)        Swap the contents of two named fields

     SkipRecord()        Remove the current record from the dataset

Here is a complete example:

```ECL
IMPORT DataPatterns;

ValRec := RECORD
    UNSIGNED2       num_violations;
    SET OF STRING   violations;
END;

LAYOUT := RECORD
    STRING  trade_date;
    STRING  exchange_code;
    STRING  stock_symbol;
    STRING  opening_price;
    STRING  high_price;
    STRING  low_price;
    STRING  closing_price;
    STRING  shares_traded;
    STRING  share_value;
    ValRec  validation_results;
END;

ds := DATASET('~thor::stock_data_validated', LAYOUT, FLAT);

repairs := 'LowPriceLessThanOrEqualToHighPrice:Swap(high_price, low_price)'
            + '; OpeningPriceValid AND ClosingPriceValid:SkipRecord()'
            + '; OpeningPriceGreaterThanOne:opening_price := \'2\''
            ;

repairResults := DataPatterns.Validation.Fix(ds, specStr := repairs);
OUTPUT(repairResults, {repairResults}, '~thor::stock_data_fixed', OVERWRITE, COMPRESSED);
```

---
<a name="benford"></a>
### Benford

Benford's law, also called the Newcomb–Benford law, or the law of anomalous
numbers, is an observation about the frequency distribution of leading digits
in many real-life sets of numerical data.

Benford's law doesn't apply to every set of numbers, but it usually applies
to large sets of naturally occurring numbers with some connection like:

* Companies' stock market values
* Data found in texts — like the Reader's Digest, or a copy of Newsweek
* Demographic data, including state and city populations
* Income tax data
* Mathematical tables, like logarithms
* River drainage rates
* Scientific data

The law usually doesn't apply to data sets that have a stated minimum and
maximum, like interest rates or hourly wages. If numbers are assigned,
rather than naturally occurring, they will also not follow the law. Examples
of assigned numbers include: zip codes, telephone numbers and Social
Security numbers.

For more information: https://en.wikipedia.org/wiki/Benford%27s_law

**Note:**  This function is also available in the ECL Standard Library
as `Std.DataPatterns.Benford()` as of HPCC version 7.12.0.

Documentation as pulled from the beginning of [Benford.ecl](Benford.ecl):

    Note that when computing the distribution of the most significant digit,
    the digit zero is ignored.  So for instance, the values 0100, 100, 1.0,
    0.10, and 0.00001 all have a most-significant digit of '1'.  The digit
    zero is considered for all other positions.

    @param   inFile          The dataset to process; REQUIRED
    @param   fieldListStr    A string containing a comma-delimited list of
                             attribute names to process; note that attributes
                             listed here must be top-level attributes (not child
                             records or child datasets); use an empty string to
                             process all top-level attributes in inFile;
                             OPTIONAL, defaults to an empty string
    @param   digit           The 1-based digit within the number to examine; the
                             first significant digit is '1' and it only increases;
                             OPTIONAL, defaults to 1, meaning the most-significant
                             non-zero digit
    @param   sampleSize      A positive integer representing a percentage of
                             inFile to examine, which is useful when analyzing a
                             very large dataset and only an estimated data
                             analysis is sufficient; valid range for this
                             argument is 1-100; values outside of this range
                             will be clamped; OPTIONAL, defaults to 100 (which
                             indicates that all rows in the dataset will be used)

    @return  A new dataset with the following record structure:

         RECORD
             STRING      attribute;   // Name of data attribute examined
             DECIMAL4_1  zero;        // Percentage of rows with digit of '0'
             DECIMAL4_1  one;         // Percentage of rows with digit of '1'
             DECIMAL4_1  two;         // Percentage of rows with digit of '2'
             DECIMAL4_1  three;       // Percentage of rows with digit of '3'
             DECIMAL4_1  four;        // Percentage of rows with digit of '4'
             DECIMAL4_1  five;        // Percentage of rows with digit of '5'
             DECIMAL4_1  six;         // Percentage of rows with digit of '6'
             DECIMAL4_1  seven;       // Percentage of rows with digit of '7'
             DECIMAL4_1  eight;       // Percentage of rows with digit of '8'
             DECIMAL4_1  nine;        // Percentage of rows with digit of '9'
             DECIMAL7_3  chi_squared; // Chi-squared "fitness test" result
             UNSIGNED8   num_values;  // Number of rows with non-zero values for this attribute
         END;

    The named digit fields (e.g. "zero" and "one" and so on) represent the
    digit found in the 'digit' position of the associated attribute.  The values
    that appear there are percentages.  num_values shows the number of
    non-zero values processed, and chi_squared shows the result of applying
    that test using the observed vs expected distribution values.

    The first row of the results will show the expected values for the named
    digits, with "-- EXPECTED DIGIT n --" showing as the attribute name.'n' will
    be replaced with the value of 'digit' which indicates which digit position
    was examined.

Sample call:

```ECL
IMPORT DataPatterns;

filePath := '~thor::stock_data_';

DataRec := RECORD
	UNSIGNED4   trade_date;
	STRING1     exchange_code;
	STRING9     stock_symbol;
	DECIMAL9_2  opening_price;
	DECIMAL9_2  high_price;
	DECIMAL9_2  low_price;
	DECIMAL9_2  closing_price;
	UNSIGNED4   shares_traded;
	UNSIGNED4   share_value;
END;

ds := DATASET(filePath, DataRec, FLAT);

// Analyze only the opening_price, closing_price, and trade_date attributes
benfordResult := DataPatterns.Benford(ds, 'opening_price, closing_price, trade_date');

OUTPUT(benfordResult, NAMED('benfordResult'), ALL);
```

The result would look something like the following:

|attribute|zero|one|two|three|four|five|six|seven|eight|nine|chi_squared|num_values|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|-- EXPECTED DIGIT 1 --|-1|30.1|17.6|12.5|9.7|7.9|6.7|5.8|5.1|4.6|20.09|20959177|
|opening_price|-1|31.7|20|13.3|9.7|7.2|5.7|4.8|4.1|3.6|1.266|19082595|
|closing_price|-1|31.7|20|13.3|9.7|7.2|5.7|4.8|4|3.6|1.307|19083933|
|trade_date|-1|0|100|0|0|0|0|0|0|0|468.182|20959177|

The result contains the attribute name, expected and actual distributions of the digit
as a percentage, the chi-squared computation indicating how well that attribute
adheres to Benford's Law, and the number of records actually considered.

By definition, the most-significant digit will never be zero.  Therefore, when computing the
distribution of the most-significant digit, the 'zero' field will show -1 for all
attributes in the result.

The chi\_squared column represents the critical value for a chi-squared test.  If an
attribute's chi\_squared value is greater than the expected chi\_squared value then that
attribute does not follow Benford's Law.

In the above example, the trade\_date attribute fails the chi-squared test, as 468.182 > 20.09.
This makes sense, because the data in that attribute is a date in YYYYMMDD format represented
as an unsigned integer, and the dataset contains stock data for only the past few years.

---
<a name="testing"></a>
### Profile() Testing

The data profiling code can be easily tested with the included Tests module.
hthor or ROXIE should be used to execute the tests, simply because Thor takes a
relatively long time to execute them.  Here is how you invoke the tests:

```ECL
IMPORT DataPatterns;
EVALUATE(DataPatterns.Tests);
```

If the tests pass then the execution will succeed and there will be no output.
These tests may take some time to execute on Thor.  They run much faster on
either hthor or ROXIE, due to the use of small inline datasets.
