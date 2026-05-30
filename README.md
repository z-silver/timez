# Timez

`timez` is a work time reporting tool. It reads in a time log file and exports a CSV.

## Building

```
zig build
```

You can use the `--release` option for an optimized executable.

## Usage

The file format expected by `timez` is very minimal: it uses plain text and is line-oriented.

There are three types of lines recognized by the tool: dates, sessions and comments.

### Date lines

A date line looks like this:

```
1999-08-01 Sun
```

It is made up of a date in ISO-8601 format, optionally followed by a space and then a comment that runs to the end of the line. When the tool encounters this line, it sets the date it will use for subsequent session lines.

### Session lines

A session line looks like this:

```
0900-0930 tv -- watching Digimon Adventure
```

It is made up of a start timestamp, a dash, an end timestamp, a project label, a separator, and finally the activity description.

The timestamps themselves are written as four digits: the first two are the hour in 24-hour format, and the last two are the minutes. No spaces are allowed either before or between the timestamps.

The project label must be separated from the timestamps and the separator by whitespace.

The separator is a pair of dashes with no space in between, followed by at least one more space.

There must be at least one date line in the file before a session line can appear. It is an error for a session line to appear with no date lines preceding it.

For convenience, we do allow timestamps with an hour greater than 23 and they properly wrap around to the next day.

### Comment lines

A comment line must start with either a space, a pound sign (`#`) or a semicolon (`;`).

Empty lines are also treated as comments.

Note that tab characters are not allowed anywhere in the file.

### Example file

```
1999-08-01 Sun
0900-0930 tv -- watching Digimon Adventure
    This episode was really great. I really like how it referenced the original OVA.
    Looking forward to the next one.

0930-1032 music -- playing bass
1032-1637 isekai -- get sucked into the Digital World

1999-09-02 Mon
1000-2500 survival training -- practicing how not to die in the Digital World
    I got carried away with this one.
```
