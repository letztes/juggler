#!/usr/bin/perl

=pod

done
* Capture the letters
* Build all possible strings
* Look strings up in a dictionary, e.g. aspell
* Print strings to command line
* Abort string progression if prefix not found in prefix index
* format stdout in three columns
* README file
* set network device dynamically

todo
* nothing

=cut
  
use strict;
use warnings;

use feature 'say';

########################################################################
# Global variables that control the behaviour of this script.
########################################################################

my $DEVICE = qx(ifconfig | grep -B1 inet | grep -B1 Bcast | awk -F '     ' '{print \$1}');

# In case the above does not work, find out active device name manually
#my $DEVICE = 'wlan0';
$DEVICE =~ s/\n+//g;

# Coordinates of the positions. Two dimensional array.
my @LETTERS;

# Load initially the dictionary file
my %DICTIONARY;
my %TWO_LETTER_INDEX;
my %THREE_LETTER_INDEX;
my %FOUR_LETTER_INDEX;
my %FIVE_LETTER_INDEX;
my %SIX_LETTER_INDEX;
my %SEVEN_LETTER_INDEX;
my %EIGHT_LETTER_INDEX;

# Don't print multiple times the same word, even if found on different
# locations
my %FOUND_WORDS;

# File handles
my $LOGFILE;
my $PACKET_LOGFILE;

########################################################################
# Subroutines
########################################################################

=head2
Fills a two dimensional hash from one dimensional array.
=cut

sub get_letters_matrix {
    my @letters = (
        [  $_[0],  $_[1],  $_[2],  $_[3]  ],
        [  $_[4],  $_[5],  $_[6],  $_[7], ],
        [  $_[8],  $_[9], $_[10], $_[11], ],
        [ $_[12], $_[13], $_[14], $_[15], ],
    );
    
    say $LOGFILE  localtime() . ' ' . " ( $letters[0][0] ) ( $letters[0][1] ) ( $letters[0][2] ) ( $letters[0][3] ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters[1][0] ) ( $letters[1][1] ) ( $letters[1][2] ) ( $letters[1][3] ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters[2][0] ) ( $letters[2][1] ) ( $letters[2][2] ) ( $letters[2][3] ) ";
    say $LOGFILE  localtime() . ' ' . " ( $letters[3][0] ) ( $letters[3][1] ) ( $letters[3][2] ) ( $letters[3][3] ) ";
    
    return @letters;
}

=head2 find_words
Calls a_star on each starting position.
=cut

sub find_words {
    say "\n------------------------------------------------------";
    
    foreach my $dim_1 (0..$#LETTERS) {
        
        foreach my $dim_2 (0..$#{$LETTERS[$dim_1]}) {
            a_star({
                'dim_1' => $dim_1,
                'dim_2' => $dim_2,
                'word'  => '',
                'visited_href' => { $dim_1 => { $dim_2 => 1} },
            });
        }
    }
    
    return;
}

=head2 is_bad_prefix
Returns true if given string does not match the beginning of any word
=cut

sub is_bad_prefix {
	my $word = shift;
	if (length($word) == 2) {
		if (not $TWO_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 3) {
		if (not $THREE_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 4) {
		if (not $FOUR_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 5) {
		if (not $FIVE_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 6) {
		if (not $SIX_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 7) {
		if (not $SEVEN_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	elsif (length($word) == 8) {
		if (not $EIGHT_LETTER_INDEX{$word}) {
			return 1;
		}
	}
	else {
		return 0;
	}
	return;
}

=head2 a_star
Not quite the original, since this one frees visited positions on
forked paths after they were explored and returned to the fork, so
the positions on that path are accessible from crossing paths later.

Expects current position, all visited positions so far and
the string built so far.

Calls get_unvisited_neighbours on current position and calls itself
recursively on each unvisited neighbour position.

Does not return any value.
=cut

sub a_star {
    my ($args) = @_;
    #say $args->{'dim_1'} . ', ' . $args->{'dim_2'};
    
	$args->{'word'} .= $LETTERS[ $args->{'dim_1'} ][ $args->{'dim_2'} ];
	$args->{'visited_href'} -> { $args->{'dim_1'} }{ $args->{'dim_2'} } = 1;
	
	# abort if prefix not found in index
	if (is_bad_prefix($args->{'word'})) {
		say $LOGFILE  localtime() . ' ' . " ... ";
		delete $args->{'visited_href'} -> { $args->{'dim_1'} }{ $args->{'dim_2'} };
		return;
	}
	
    # only words longer than 3 letters are accepted
    if (length($args->{'word'}) > 2) {
        # lookup in dictionary and say word only if exists
        if ($DICTIONARY{ $args->{'word'} }) {
            if (not $FOUND_WORDS{ $args->{'word'} }) {
                $FOUND_WORDS{ $args->{'word'} } = 1;
                say $LOGFILE localtime() . ' ' . $args->{'word'} or die $!;
                print sprintf("%-20s", $args->{'word'});
                print "\n" if (scalar keys %FOUND_WORDS) % 3 == 0;
            }
        }
    }
        
    my @neighbour_coordinates = get_unvisited_neighbours({
        'dim_1' => $args->{'dim_1'},
        'dim_2' => $args->{'dim_2'},
        'visited_href' => $args->{'visited_href'},
    });
    
    if (not @neighbour_coordinates) {
		delete $args->{'visited_href'} -> { $args->{'dim_1'} }{ $args->{'dim_2'} };
		return;
	}
    
    foreach my $neighbour_coordinates (@neighbour_coordinates) {
        say $LOGFILE localtime() . ' ' . $neighbour_coordinates->[0] . ', ' . $neighbour_coordinates->[1] . ', ' . $args->{'word'} . $LETTERS[ $neighbour_coordinates->[0] ][ $neighbour_coordinates->[1] ] or die $!;
        
        # need a disposable one for every path to try
        my %disposable_visited = %{ $args->{'visited_href'} };
        
        a_star({
            'dim_1'   => $neighbour_coordinates->[0],
            'dim_2'   => $neighbour_coordinates->[1],
            'word'    => $args->{'word'},
            'visited_href' => \%disposable_visited,
        });
    
        
    }

    # delete the last pair of coordinates since we are moving back
    # the recursion and the coordinates visited on the previous
    # path should be accessible again in an alternative path
	delete $args->{'visited_href'} -> { $args->{'dim_1'} }{ $args->{'dim_2'} };
    
    return;
}

=head2 get_unvisited_neighbours
Expects current position and list of positions visited so far.
Returns all adjacent positions that were not yet visited.
=cut

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

=head2 fill_dictionary
Reads dictionary file.
Builds some indices as well.
=cut

sub fill_dictionary {
    say 'open dictionary file...';
    #open(my $WORDSTREAM, qq[aspell -l de dump master | aspell -l de expand | tr ' ' '\n'|]);
    open(my $WORDSTREAM, 'dictionary.txt');
    while (my $word = <$WORDSTREAM>) {
        $word =~ s/ä/ae/gi;
        $word =~ s/ö/oe/gi;
        $word =~ s/ü/ue/gi;
        $word =~ s/ß/ss/gi;
        $word =~ s/Ä/AE/gi;
        $word =~ s/Ö/OE/gi;
        $word =~ s/Ü/UE/gi;
        next if length($word) < 3;
        next if length($word) > 16;
        chomp $word;
        $DICTIONARY{uc($word)} = 1;
        
		$TWO_LETTER_INDEX{uc(substr($word, 0, 2))} = 1;
		$THREE_LETTER_INDEX{uc(substr($word, 0, 3))} = 1;
        if (length($word) > 3) {
			$FOUR_LETTER_INDEX{uc(substr($word, 0, 4))} = 1;
			if (length($word) > 4) {
				$FIVE_LETTER_INDEX{uc(substr($word, 0, 5))} = 1;
				if (length($word) > 5) {
					$SIX_LETTER_INDEX{uc(substr($word, 0, 6))} = 1;
                    if (length($word) > 6) {
                        $SEVEN_LETTER_INDEX{uc(substr($word, 0, 6))} = 1;
                        if (length($word) > 7) {
                            $EIGHT_LETTER_INDEX{uc(substr($word, 0, 6))} = 1;
                        }
                    }
				}
			}
			
		}
		
    }
    say 'done reading ' . (scalar (keys %DICTIONARY)) . ' words.';
    return;
}

=head2 main
The main routine.
=cut

sub main {
    open($LOGFILE, '>logfile.txt') or die $!;
    open($PACKET_LOGFILE, '>packet_logfile.txt') or die $!;
    open(my $NETTRAFFIC, "sudo tcpdump -i $DEVICE -Aln host 193.254.186.182 or host 193.254.186.183 or host 194.112.167.227 or host 213.95.79.43 -s 0|") or die $!;
    fill_dictionary();
    
    while (my $packet = <$NETTRAFFIC>) {
        exit if $packet =~ m/Abschied|Gratulation/;
        say $PACKET_LOGFILE localtime() . ' ' .  $packet or die $!;
        
        if (my @letters = $packet =~ m/([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)#([A-Z]|Qu)$/) {
            
            @LETTERS = get_letters_matrix(@letters);
            find_words();
        }
    }
    close($NETTRAFFIC);
    close($PACKET_LOGFILE);
    close($LOGFILE);
    exit;
}

&main();


















