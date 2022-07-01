#!usr/bin/perl

use v5.14;

package App::Gram::Reducer;

use strict;
use warnings FATAL => 'all';
use experimental qw( switch );

use Data::Dumper;
use List::Util qw(all any);
use Scalar::Util qw(looks_like_number blessed);

sub new {
    my $class = shift;
    my ($finished_groups, $rules) = @_;
    my $self = {
        _acc_groups      => {},
        _finished_groups => $finished_groups,
        _rules           => $rules
    };
    bless $self, $class;
    return $self;
}

sub reduce {
    my ($self, $expr) = @_;

    $self->_reduce_expr($expr);  # Main reduce subroutine
    $self->_release_finished();
}

sub end {
    my ($self) = @_;
    my $acc_groups = $self->{_acc_groups};

    foreach my $key (sort keys %$acc_groups) {
        my $rule_groups = $acc_groups->{$key};
        map {$_->{finished} = 1;} @$rule_groups;
    }
    $self->_release_finished();
}

sub _release_finished {
    my ($self) = @_;
    my $acc_groups = $self->{_acc_groups};
    my $finished_groups = $self->{_finished_groups};

    foreach my $key (sort keys %$acc_groups) {
        my $rule_groups = $acc_groups->{$key};
        my $finished_group = $finished_groups->{$key};
        $finished_groups->{$key} = [] if (ref($finished_group) ne "ARRAY");

        push @{$finished_groups->{$key}}, grep {$_->{finished}} @$rule_groups;
        @{$acc_groups->{$key}} = grep {!$_->{finished}} @$rule_groups;
    }
}

sub _reduce_expr {
    my ($self, $expr) = @_;

    my $acc_groups = $self->{_acc_groups};
    my $rules = $self->{_rules};

    if (defined $expr) {
        foreach my $rule_name (sort keys %$rules) {
            my $rule = $rules->{$rule_name};
            if (exists($acc_groups->{$rule_name})) {
                my $rule_groups = $acc_groups->{$rule_name};
                my $chained_group;
                foreach my $rule_group (@$rule_groups) {
                    my @expr_chain = @{$rule_group->{expr_chain}};
                    my $last_expr = $expr_chain[$#expr_chain];
                    if (check_rule_expr($rule, $expr, $last_expr)) {
                        # say "Add expr to expr chain";
                        $chained_group = $rule_group;
                        push @{$rule_group->{expr_chain}}, $expr;
                    }
                }
                map {
                    $_->{finished} = 1;  # Has finished
                } defined $chained_group
                    ? grep {$_ != $chained_group} @$rule_groups  # Without chained group
                    : @$rule_groups;  # All rule groups

                if (!$chained_group && check_rule_expr($rule, $expr)) {
                    # say "Add rule group to rule groups";
                    push @$rule_groups, {
                        expr_chain => [$expr]
                    }
                }
            } else {
                if (check_rule_expr($rule, $expr)) {
                    # say "Set rule groups in acc groups";
                    $acc_groups->{$rule_name} = [
                        {
                            expr_chain => [$expr]
                        }
                    ];
                }
            }
        }
    } else {
        # End reduce
        foreach my $key (sort keys %$acc_groups) {
            my $rule_groups = $acc_groups->{$key};
            map {$_->{finished} = 1;} @$rule_groups;
        }
    }
}

sub is_equal_values {
    my ($a, $b) = @_;
    if (looks_like_number($a) && looks_like_number($b)) {
        return $a == $b;
    } elsif (ref($a) eq ref($b)) {
        return $a eq $b;
    }
};

sub check_rule_expr {
    my ($rule, $expr, $prev_expr) = @_;
    return all {
        my $key = $_;
        my $rule_value = $rule->{$key};
        my $prop;
        if ($key =~ s/:([^:]+)//g) {  # Find and remove all props (and save last prop)
            $prop = $1;
        };
        # print "KEY: ", $key, Dumper $rule, $expr, $prev_expr;
        return 0 unless exists $expr->{$key} && $expr->{$key};

        my $expr_value = $expr->{$key};
        my $ref_expr_value = ref($expr_value);
        # Issue: given make $_ scoped variable
        if ($ref_expr_value eq "ARRAY") {
            if ($prop eq "any") {
                any {
                    my $expr_value_item = $_;
                    if (defined $prev_expr) {
                        any {
                            check_rule_expr($rule_value, $expr_value_item, $_);
                        } @{$prev_expr->{$key}};
                    } else {
                        check_rule_expr($rule_value, $expr_value_item);
                    }
                } @$expr_value;
            }
        }
        elsif ($ref_expr_value eq "HASH") {
            unless (defined $prop) {
                check_rule_expr($rule_value, $expr_value, defined $prev_expr ? $prev_expr->{$key} : undef);
            }
        }
        else {
            my $ref_key;
            if ($rule_value =~ /&(.+)/) {
                $ref_key = $1;
            }
            if (defined $ref_key) {
                if (defined $prev_expr) {
                    # say "ref_key: ", $expr_value, ", ", $prev_expr->{$ref_key};
                    is_equal_values($expr_value, $prev_expr->{$ref_key});
                } else {
                    1;
                }
            } else {
                # say "prop: ", $rule_value, ", ", $expr_value;
                is_equal_values($rule_value, $expr_value);
            }
        }
    } sort keys %$rule;
}

1;
