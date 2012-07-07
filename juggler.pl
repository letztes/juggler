#!/usr/bin/perl

=pod

* Capture the letters
* Build all possible strings
* Look strings up in a dictionary, e.g. aspell
* Print strings to command line
* Print strings into the ether


=cut
  
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use Getopt::Long qw(:config bundling);
use HTTP::Request::Common;
use LWP;
use Pod::Usage;
use URI::Escape;


########################################################################
# Global variables that control the behaviour of this script.
########################################################################

my $DEVICE = 'wlan0';

# Coordinates are keys in two dimensional hash
my %LETTERS;

# Load initially the dictionary file
my %DICTIONARY;

# Don't print multiple times the same word, even if found on different
# locations
my %FOUND_WORDS;

# File handles
my $LOGFILE;
my $PACKET_LOGFILE;

########################################################################
# Subroutines
########################################################################


sub get_letters_hash {
    my @letters = @_;
    my %letters = (
        0 => {
            0 => $letters[0],
            1 => $letters[1],
            2 => $letters[2],
            3 => $letters[3],
        },
        1 => {
            0 => $letters[4],
            1 => $letters[5],
            2 => $letters[6],
            3 => $letters[7],
        },
        2 => {
            0 => $letters[8],
            1 => $letters[9],
            2 => $letters[10],
            3 => $letters[11],
        },
        3 => {
            0 => $letters[12],
            1 => $letters[13],
            2 => $letters[14],
            3 => $letters[15],
        },
    );
    
    say $LOGFILE  localtime() . ' ' . " ( $letters{0}{0} ) ( $letters{0}{1} ) ( $letters{0}{2} ) ( $letters{0}{3} ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters{1}{0} ) ( $letters{1}{1} ) ( $letters{1}{2} ) ( $letters{1}{3} ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters{2}{0} ) ( $letters{2}{1} ) ( $letters{2}{2} ) ( $letters{2}{3} ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters{3}{0} ) ( $letters{3}{1} ) ( $letters{3}{2} ) ( $letters{3}{3} ) ";
    
    return %letters;
}

sub find_words {
    say '------------------------------------------------------';
    
    foreach my $dim_1 (sort keys %LETTERS) {
        
        foreach my $dim_2 (sort keys %{$LETTERS{$dim_1}}) {
            a_star({
                'dim_1' => $dim_1,
                'dim_2' => $dim_2,
                'word'  => $LETTERS{ $dim_1 }{ $dim_2 },
                'visited_href' => { $dim_1 => { $dim_2 => 1} },
            });
        }
    }
    
    return;
}

sub a_star {
    my ($args) = @_;
    #say $args->{'dim_1'} . ', ' . $args->{'dim_2'};
    
    # only words longer than 3 letters are accepted
    if (length($args->{'word'}) > 2) {
        # lookup in dictionary and say word only if exists
        if ($DICTIONARY{ $args->{'word'} }) {
            if (not $FOUND_WORDS{ $args->{'word'} }) {
                say $LOGFILE localtime() . ' ' . $args->{'word'} or die $!;
                say $args->{'word'};
                $FOUND_WORDS{ $args->{'word'} } = 1;
            }
        }
    }
        
    my @neighbour_coordinates = get_unvisited_neighbours({
        'dim_1' => $args->{'dim_1'},
        'dim_2' => $args->{'dim_2'},
        'visited_href' => $args->{'visited_href'},
    });
    return if (not @neighbour_coordinates);
    
    foreach my $neighbour_coordinates (@neighbour_coordinates) {
        say $LOGFILE localtime() . ' ' . $neighbour_coordinates->[0] . ', ' . $neighbour_coordinates->[1] . ', ' . $args->{'word'} . $LETTERS{ $neighbour_coordinates->[0] }{ $neighbour_coordinates->[1] } or die $!;
        $args->{'visited_href'} -> { $neighbour_coordinates->[0] }{ $neighbour_coordinates->[1] } = 1;
        a_star({
            'dim_1'   => $neighbour_coordinates->[0],
            'dim_2'   => $neighbour_coordinates->[1],
            'word'    => $args->{'word'} . $LETTERS{ $neighbour_coordinates->[0] }{ $neighbour_coordinates->[1] },
            'visited_href' => $args->{'visited_href'},
        });
    
        
        # delete the last pair of coordinates since we are moving back
        # the recursion and the coordinates visited on the previous
        # path should be accessible again in an alternative path
    }
        delete $args->{'visited_href'} -> { $args->{'dim_1'} }{ $args->{'dim_2'} };
    
    return;
}

sub get_unvisited_neighbours {
    my ($args) = @_;
    
    my @unvisited_neighbours;
    
    for my $possible_arg_1 ($args->{'dim_1'} - 1 .. $args->{'dim_1'} + 1) {
        next if $possible_arg_1 < 0;
        next if $possible_arg_1 > 3;
        for my $possible_arg_2 ($args->{'dim_2'} - 1 .. $args->{'dim_2'} + 1) {
            next if $possible_arg_2 < 0;
            next if $possible_arg_2 > 3;
            next if exists $args->{'visited_href'} -> { $possible_arg_1 }{ $possible_arg_2 };
            push(@unvisited_neighbours, [$possible_arg_1, $possible_arg_2]);
        }
    }
    return @unvisited_neighbours;
}

sub fill_dictionary {
    say 'open dictionary file...';
    #open(my $WORDSTREAM, qq[aspell -l de dump master | aspell -l de expand | tr ' ' '\n'|]);
    open(my $WORDSTREAM, 'dictionary.txt');
    while (my $word = <$WORDSTREAM>) {
        $word =~ s/ä/ae/g;
        $word =~ s/ö/oe/g;
        $word =~ s/ü/ue/g;
        $word =~ s/ß/ss/g;
        next if length($word) < 3;
        next if length($word) > 16;
        chomp $word;
        $DICTIONARY{uc($word)} = 1;
    }
    say 'done reading ' . (scalar (keys %DICTIONARY)) . ' words.';
    return;
}

sub main {
    open($LOGFILE, '>logfile.txt') or die $!;
    open($PACKET_LOGFILE, '>packet_logfile.txt') or die $!;
    open(my $NETTRAFFIC, "sudo tcpdump -i $DEVICE -Aln host 193.254.186.182 or host 193.254.186.183 or host 194.112.167.227 or host 213.95.79.43 -s 0|") or die $!;
    fill_dictionary();
    
    while (my $packet = <$NETTRAFFIC>) {
        exit if $packet =~ m/Abschied/;
        say $PACKET_LOGFILE localtime() . ' ' .  $packet or die $!;
        if (my @letters = $packet =~ m/([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])$/) {
        #if (my @letters = 'gJuggle2#JuggleBoTina#27#0#i#2#180#E#A#C#L#S#O#T#L#N#E#E#R#A#C#S#B' =~ m/Juggle.+#JuggleBoT.+#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])#([A-Z])$/) {
            #say $packet;
            #say Dumper(@letters);
            %LETTERS = get_letters_hash(@letters);
            find_words();
        }
    }
    close($NETTRAFFIC);
    close($PACKET_LOGFILE);
    close($LOGFILE);
    exit;
}



&main();


















