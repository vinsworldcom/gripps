#!/usr/bin/perl
##################################################
# AUTHOR = Michael Vincent
# www.VinsWorld.com
##################################################

use vars qw($VERSION);

$VERSION = "1.05 - 21 JUL 2015";

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case);    #bundling
use Pod::Usage;

##################################################
# Start Additional USE
##################################################

##################################################
# End Additional USE
##################################################

my ( %opt, %opts );
my ( $opt_help, $opt_man, $opt_versions );

# Defaults
$opt{grid}    = 1;
$opt{numbers} = 1;

GetOptions(
    'barmeter!'    => \$opt{bar},
    'debug!'       => \$opt{debug},
    'grid!'        => \$opt{grid},
    'm|multiple!'  => \$opt{multi},
    'n|numerical!' => \$opt{numbers},
    'reuse!'       => \$opt{reuse},
    'write!'       => \$opt{write},
    'key=s@'       => \$opts{key},
    'Title=s@'     => \$opts{title},
    'Xlabel=s@'    => \$opts{xlabel},
    'xrange=i@'    => \$opts{xrange},
    'Ylabel=s@'    => \$opts{ylabel},
    'ym|ymin=f@'   => \$opts{ymin},
    'yM|ymax=s@'   => \$opts{ymax},
    'help!'        => \$opt_help,
    'man!'         => \$opt_man,
    'versions!'    => \$opt_versions
) or pod2usage( -verbose => 0 );

pod2usage( -verbose => 1 ) if defined $opt_help;
pod2usage( -verbose => 2 ) if defined $opt_man;

if ( defined $opt_versions ) {
    print
      "\nModules, Perl, OS, Program info:\n",
      "  $0\n",
      "  Version               $VERSION\n",
      "    strict              $strict::VERSION\n",
      "    warnings            $warnings::VERSION\n",
      "    Getopt::Long        $Getopt::Long::VERSION\n",
      "    Pod::Usage          $Pod::Usage::VERSION\n",
##################################################
      # Start Additional USE
##################################################

##################################################
      # End Additional USE
##################################################
      "    Perl version        $]\n",
      "    Perl executable     $^X\n",
      "    OS                  $^O\n",
      "\n\n";
    exit;
}

##################################################
# Start Program
##################################################

# Assign number of streams
my $numStreams = 0;
if ( !@ARGV ) {
    $numStreams = 1;
} else {
    $numStreams = $ARGV[0];

    # drop any remaining args
    for (@ARGV) {
        shift @ARGV;
    }
}

# If reuse, assign reused args for each stream
if ( defined( $opt{reuse} ) ) {
    for my $arg ( keys(%opts) ) {
        if ( defined( $opts{$arg} ) and ( @{$opts{$arg}} != $numStreams ) ) {
            for ( my $i = $#{$opts{$arg}} + 1; $i < $numStreams; $i++ ) {
                $opts{$arg}->[$i] = $opts{$arg}->[$#{$opts{$arg}}];
            }
        }
    }
}

if ( $opt{debug} ) {
    use Data::Dumper;
    print Dumper \%opts;
}

my @buffers;
my @gnuplots;    # holds '|gnuplot' file handles
my @gnufiles;    # holds .plt output file handles
my @datfiles;    # holds .csv output file handles
my @datnames;    # holds .csv output file names
for my $i ( 0 .. $numStreams - 1 ) {

    my @fhs; # holds all file handles to print to (output file [if -w] and |gnuplot)

    # Outfile
    if ( defined $opt{write} ) {

        # create output file names
        my $gnufile = yyyymmddhhmmss() . "-" . $$ . "-" . ( $i + 1 );
        my $datfile = $gnufile . ".csv";
        $gnufile .= ".plt";

        # open output .plt files and make autoflush
        do {
            open my $outfh, '>', $gnufile
              or die "$0: Can't open output Gnuplot file - $gnufile\n";
            select($outfh);
            $| = 1;
            select STDOUT;
            push @gnufiles, $outfh;
            push @fhs,      $outfh;

            # only do it once if multiplot
        } unless ( defined( $opt{multi} ) && ( $i > 0 ) );

        # open output .csv files and make autoflush
        open my $datfh, '>', $datfile
          or die "$0: Can't open output data file - $datfile\n";
        select($datfh);
        $| = 1;
        select STDOUT;
        push @datfiles, $datfh;
        push @datnames, $datfile;
    }

    my @data = [];
    push @buffers, @data;
    next if ( defined( $opt{multi} ) and ( $i > 0 ) );

    # Gnuplot pipe
    open my $pip, '|-', "gnuplot"
      or die "$0: Can't initialize gnuplot number " . ( $i + 1 ) . "\n";
    select( ( select($pip), $| = 1 )[0] );
    push @gnuplots, $pip;
    push @fhs,      $pip;

    # like tee, print to |gnuplot and output .plt files if -w was defined
    for my $fh (@fhs) {
        print $fh "set xtics\n";
        print $fh "set ytics\n";
        # print $fh "set style line 1 lw 3\n";
        if ( defined $opts{xlabel}->[$i] ) {
            printf $fh "set xlabel \"%s\"\n", $opts{xlabel}->[$i];
        }
        if ( defined $opts{ylabel}->[$i] ) {
            printf $fh "set ylabel \"%s\"\n", $opts{ylabel}->[$i];
        }
        if ( defined $opts{title}->[$i] ) {
            printf $fh "set title \"%s\"\n", $opts{title}->[$i];
        }
        if ( defined( $opts{ymin}->[$i] ) and defined( $opts{ymax}->[$i] ) ) {
            print $fh "set yrange ["
              . $opts{ymin}->[$i] . ":"
              . $opts{ymax}->[$i] . "]\n";
        }
        print $fh "set style data linespoints\n";
        if ( $opt{grid} ) {
            print $fh "set grid\n";
        }
    }
}

# Ctrl-C handler
my $stopRepeat = 0;
$SIG{'INT'} = sub {
    print "SIGINT! - Stop\n";
    $stopRepeat = 1;
};

my $streamIdx = 0;
select( ( select(STDOUT), $| = 1 )[0] );
my $xcounter = 0;

# read STDIN
while (my $data = <>) {
    chomp $data;
    my $buf = $buffers[$streamIdx];

    my $pip;    # |gnuplot file handle
    my $gnu;    # .plt output file handle
    if ( defined $opt{multi} ) {
        $pip = $gnuplots[0];
        $gnu = $gnufiles[0];
    } else {
        $pip = $gnuplots[$streamIdx];
        $gnu = $gnufiles[$streamIdx];
    }
    my $dat = $datfiles[$streamIdx];    # .csv output file handle
    my $nam = $datnames[$streamIdx];    # .csv output file name

    # User ended endless repeat with CTRL-C?
    last if ($stopRepeat);

    # make sure input is numerical (+/- number . number or exponent)
    if ( $opt{numbers} ) {
        if ( $data !~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/ ) {
            $data = 0;
        }
    }

    push @{$buf}, $data;

    # bar graph - xrange is -1<->1, centered on 0
    # if multi (all on 1 graph, -1<->$numStreams (multi on the graph)
    if ( defined $opt{bar} ) {
        $opts{xrange}->[$streamIdx] = 1;
        do {
            printf $pip "set xrange [-1:%i]\n",
              defined( $opt{multi} ) ? $numStreams : 1;
        } unless ( defined( $opt{multi} ) and ( $streamIdx > 0 ) );
    } else {
        do {
            if ( defined $opts{xrange}->[$streamIdx] ) {
                print $pip "set xrange ["
                  . ( $xcounter - $opts{xrange}->[$streamIdx] ) . ":"
                  . ( $xcounter + 1 ) . "]\n";
            }
        } unless ( defined( $opt{multi} ) and ( $streamIdx > 0 ) );
    }

    # Print:
    # 1) pipe
    if ( defined( $opt{multi} ) and ( $streamIdx == 0 ) ) {
        printf $pip "plot \"-\" title %s",
          ( defined $opts{key}->[$streamIdx] )
          ? "\"" . $opts{key}->[$streamIdx] . "\""
          : "\"Stream 1\"";
        printf $pip ", \"-\" title %s",
          ( defined $opts{key}->[$_] )
          ? "\"" . $opts{key}->[$_] . "\""
          : "\"Stream " . ( $_ + 1 ) . "\""
          for ( 1 .. $numStreams - 1 );
        print $pip "\n";
    }
    if ( not defined $opt{multi} ) {
        printf $pip "plot \"-\" %s\n",
          ( defined $opts{key}->[$streamIdx] )
          ? "title \"" . $opts{key}->[$streamIdx] . "\""
          : "notitle";
    }

    # 2) outfile
    if ( defined $gnu ) {
        if ( $xcounter == 0 ) {
            if ( defined( $opt{multi} ) and ( $streamIdx == 0 ) ) {
                print $gnu "set datafile separator \",\"\n";
                printf $gnu "plot \"$nam\" title %s",
                  ( defined $opts{key}->[$streamIdx] )
                  ? "\"" . $opts{key}->[$streamIdx] . "\""
                  : "\"Stream 1\"";
                printf $gnu ", \"$datnames[$_]\" title %s",
                  ( defined $opts{key}->[$_] )
                  ? "\"" . $opts{key}->[$_] . "\""
                  : "\"Stream " . ( $_ + 1 ) . "\""
                  for ( 1 .. $#datnames );
                print $gnu "\n";
            }
            if ( not defined $opt{multi} ) {
                print $gnu "set datafile separator \",\"\n";
                printf $gnu "plot \"$nam\" %s\n",
                  ( defined $opts{key}->[$streamIdx] )
                  ? "title \"" . $opts{key}->[$streamIdx] . "\""
                  : "notitle";
            }
        }
        print $dat "$xcounter,$data\n";
    }
    my $cnt = 0;
    for my $elem ( reverse @{$buf} ) {

        # bar graph needs to print origin and the data point
        if ( defined $opt{bar} ) {
            printf $pip "%i 0\n", defined( $opt{multi} ) ? $streamIdx : 0; # origin
            printf $pip "%i $elem\n",
              defined( $opt{multi} ) ? $streamIdx : 0    # data point
        } else {
            print $pip ( $xcounter - $cnt ) . " " . $elem . "\n";
        }
        $cnt += 1;
    }
    print $pip "e\n";
    if ( defined $opts{xrange}->[$streamIdx] ) {
        if ( $cnt >= $opts{xrange}->[$streamIdx] ) {
            shift @{$buf};
        }
    }

    $streamIdx++;
    if ( $streamIdx == $numStreams ) {
        $streamIdx = 0;
        $xcounter++;
    }
}

# clean up - Ctrl-C handler breaks while loop and program resumes here
for my $i ( 0 .. $numStreams - 1 ) {

    do {
        my $pip = $gnuplots[$i];
        print $pip "exit;\n";
        close $pip;
        if ( defined $opt{write} ) {
            my $gnu = $gnufiles[$i];
            close $gnu;
        }
    } unless ( defined( $opt{multi} ) and ( $i > 0 ) );

    if ( defined $opt{write} ) {
        my $dat = $datfiles[$i];
        close $dat;
    }
}

exit 0;

##################################################
# End Program
##################################################

##################################################
# Begin Subroutines
##################################################
sub yyyymmddhhmmss {
    my @time = localtime();
    return (
        ( $time[5] + 1900 )
        . (   ( ( $time[4] + 1 ) < 10 )
            ? ( "0" . ( $time[4] + 1 ) )
            : ( $time[4] + 1 )
          )
          . ( ( $time[3] < 10 ) ? ( "0" . $time[3] ) : $time[3] )
          . ( ( $time[2] < 10 ) ? ( "0" . $time[2] ) : $time[2] )
          . ( ( $time[1] < 10 ) ? ( "0" . $time[1] ) : $time[1] )
          . ( ( $time[0] < 10 ) ? ( "0" . $time[0] ) : $time[0] )
    );
}

##################################################
# End Program
##################################################

__END__

##################################################
# Start POD
##################################################

=head1 NAME

GRIPPS - Gnuplot Real-time Interactive Plotting Perl Script

=head1 SYNOPSIS

 gripps [options] [numStreams]
 <command> | perl gripps [options] [numStreams]

=head1 DESCRIPTION

Takes input via a command pipe or STDIN.  Input data provides the
Y-values to plot.  X-axis will be time in seconds as determined
by how quickly the input is delivering the Y-values to the script.

=head1 OPTIONS

 numStreams       Number of individual streams in the incoming pipe data.
                  DEFAULT:  (or not specified) 1.

 -b               Use bar meter graph.  Bar amplitude graphs data and
 --barmeter       does not scroll on X-axis.
                  DEFAULT:  (or not specified) line graph.

 -d               Turn on debug - print input option expansion.
 --debug          DEFAULT:  (or not specified) [off].

 -g               Use grid on graphs.  Use --nogrid to turn off.
 --grid           DEFAULT:  (or not specified) [use grid].

 -k key           Stream title in graph key.
 --key            DEFAULT:  (or not specified) [no key].

 -m               Plot each stream of numStreams on the same graph.
 --multiple       Implies -k.
                  DEFAULT:  (or not specified) [unique graph per stream].

 -n               If input is non-numerical, assume 0.
 --numerical      Use --nonumerical to keep input as is.
                  DEFAULT:  (or not specified) [non-numerical = 0].

 -r               If numStreams is greater than the number of
 --reuse          any provided options, use the last value of option
                  as the value for all remaining instances of option
                  to complete numStreams.
                  DEFAULT:  (or not specified) [use default values].

 -T title         Graph Title.  Repeat as necessary for numStreams.
 --Title          DEFAULT:  (or not specified) [none].

 -w               Save GnuPlot commands and data to unique output file
 --write          for each numStreams.  Output files are:
                    YYYYMMDDHHMMSS-<PID>-#.plt (Gnuplot commands)
                    YYYYMMDDHHMMSS-<PID>-#.csv (plot data)

                  Where <PID> is the process ID of this script and # is
                  the data stream number.
                  DEFAULT:  (or not specified) [no output file].

 -x #             X range.  Repeat as necessary for numStreams.
 --xrange         DEFAULT:  (or not specified) [default].

 -X label         X-axis label.  Repeat as necessary for numStreams.
 --Xlabel         DEFAULT:  (or not specified) [default].

 -ym #            Y minimum.  Repeat as necessary for numStreams.
 --ymin           Must use -ymax also to take effect.
                  DEFAULT:  (or not specified) [default].

 -yM #            Y maximum.  Repeat as necessary for numStreams.
 --ymax           Must use -ymin also to take effect.
                  DEFAULT:  (or not specified) [default].

 -Y label         Y-axis label.  Repeat as necessary for numStreams.
 --Ylabel         DEFAULT:  (or not specified) [default].

 --help           Print Options and Arguments.
 --man            Print complete man page.
 --versions       Print Modules, Perl, OS, Program info.

=head1 EXAMPLES

=head2 GRAPH CPU AND MEMORY ON WINDOWS

Using the command line C<typeperf> command, CPU and memory utilization
on Windows can be graphed.  A Perl one-liner takes the output of the
command and presents it in a form the script can use.

  typeperf "\Processor(_Total)\% Processor Time" "\Memory\% Committed Bytes In Use" |
  perl -an -F, -e "next if($_=~/[A-Za-z]|(^\n$)/);$|=1;$_=~s/\x22//g for(@F);printf\"$F[1]\n$F[2]\"" |
  gripps 2 --multi -T "CPU and Memory Percentage" -X "Time (sec)" -Y Percent -x 50 -ymin 0 -ymax 100 -k CPU -k Memory

=head1 LICENSE

This software is released under the same terms as Perl itself.
If you don't know what that means visit L<http://perl.com/>.

=head1 AUTHOR

Copyright (C) Michael Vincent 2010-2015

L<http://www.VinsWorld.com>

All rights reserved

=cut
