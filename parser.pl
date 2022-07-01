
use v5.14;

use strict;
use warnings;

use JSON;
use Data::Dumper;
use Regexp::Grammars;
use List::Util qw(all);
use Scalar::Util qw(looks_like_number);

use open qw(:encoding(UTF-8) :std);  # For open file in UTF-8 encoding

use lib 'lib';
use App::Gram::Reducer qw();
use App::SQLite::Schema qw();

my $schema = App::SQLite::Schema->connect('dbi:SQLite:db/numerals.db', '', '', {sqlite_unicode => 1});

sub match_words {
    my $word = shift;
    my @words = $schema->resultset('Dictionary')->search({word => lc $word});
    if (@words) {
        # map {print Dumper $_->main_word;} @words;
        return [
            map {
                {
                    morph => $_->morph,
                    value => $_->value
                };
            } @words
        ];
    } else {
        return undef;
    }
}

# my $re = qr{
#     (?(DEFINE)
#         (?<cyrillic_word> [\p{Cyrillic}\p{Inherited}]+)
#         (?<latin_word>    [\p{Latin}\p{Inherited}]+)
#     )
# }xp;

# Remove after: match field in regexp
my $parser = qr{
    <nocontext:>
    <[expression]>+ % \s*  # Separator is important for right $INDEX value

    <rule: expression>
        <index=(?{ $INDEX })>
        (
            <type='word'>
            <alphabet='cyrillic'>
            <word=cyrillic_word>
            <matches=(?{ match_words($MATCH{word}) })>
            |
            <type='word'>
            <alphabet='latin'>
            <word=latin_word>
            |
            <type='number'>
            <number>
            |
            <other>
        )

    <rule: cyrillic_word> [\p{Cyrillic}\p{Inherited}]+
    <rule: latin_word>    [\p{Latin}\p{Inherited}]+
    <rule: number> [+-]?\d+\.?\d*
    <rule: other> .+?
}x;

my $rules = {
    "numerals" => {
        "matches:any" => {
            morph => {
                class => "numeral",
                case  => "&case"
            }
        }
    }
};

my $finished_groups = {};
my $reducer = App::Gram::Reducer->new($finished_groups, $rules);


my $expressions = [];
my $index = 0;
while (my $line = <STDIN>) {
    if ($line =~ $parser) {
        my @line_expressions = @{$/{'expression'}};
        foreach my $expr (@line_expressions) {
            $expr->{index} += $index;
            # print Dumper $expr;
            $reducer->reduce($expr);
        }
        push @$expressions, @line_expressions;
        $index += length $line;
    }
}
$reducer->end();  # End reduce

sub calculate_numeral_value {
    my ($values) = @_;
    my $acc_value = shift @$values;
    foreach my $curr_value (@$values) {
        if ($acc_value < $curr_value) {  # TODO: better think how it should be work
            $acc_value *= $curr_value;  # 3, 1000 -> 3000
        } else {
            $acc_value += $curr_value;  # 100, 40 -> 140
        }
    }
    return $acc_value;
}

# Calculate finished groups values
my $numerals_groups = $finished_groups->{numerals};
foreach my $numerals_group (@$numerals_groups) {
    my $expr_chain = $numerals_group->{expr_chain};
    my $values = [map {$_->{matches}->[0]->{value}} @$expr_chain];
    if (all {looks_like_number($_)} @$values) {
        $numerals_group->{numeral_value} = calculate_numeral_value($values);
    }
}

my $json = JSON->new;
$json->canonical(1);  # https://metacpan.org/pod/JSON#canonical
print $json->encode($finished_groups);
