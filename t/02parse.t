#!/usr/bin/perl

use strict;
use warnings;
use Data::Compare;
use Data::Dumper;
use File::Spec::Functions;
use OPTIMADE::Filter::Parser;
use Test::More;

$Data::Dumper::Sortkeys = 1;

my $input_dir  = catdir( 'tests', 'cases' );
my $output_dir = catdir( 'tests', 'outputs' );

opendir my $dir, $input_dir || die "Cannot open directory: $!";
my @inputs = sort grep { /\.inp$/ } readdir $dir;
closedir $dir;

my $ntests = @inputs;
plan tests => $ntests;

for my $case (@inputs) {
    $case =~ /([^\/\\]+)\.inp$/;
    my $input_file   = catdir( $input_dir,  $case );
    my $options_file = catdir( $input_dir,  "$1.opt" );
    my $output_file  = catdir( $output_dir, "$1.out" );

    my $options = {};
    if( -e $options_file ) {
        open( my $inp, '<', $options_file );
        while( <$inp> ) {
            chomp;
            $options->{$_} = 1;
        }
        close $inp;
    }

    $OPTIMADE::Filter::Parser::allow_LIKE_operator =
        defined $options->{allow_LIKE_operator};    

    my( $tree, $output );
    my $parser = new OPTIMADE::Filter::Parser;
    eval {
        $tree = $parser->Run( $input_file );
    };
    $output = $@ if $@;

    if( $tree ) {
        $output .= Dumper( $tree ) .
                   "== Filter ==\n" .
                   $tree->to_filter . "\n" .
                   "== SQL ==\n";
    }

    if( $tree ) {
        my $sql_options = {};
        if( exists $options->{flatten} ) {
            $sql_options->{flatten} = $options->{flatten};
        }
        eval {
            if( $options->{use_placeholders} ) {
                $sql_options->{placeholder} = '?';
                my( $sql, $values ) = $tree->to_SQL( $sql_options );
                $output .= "$sql\n" .
                           "=== Values ===\n" .
                           Dumper $values;
            } else {
                $output .= $tree->to_SQL( $sql_options ) . "\n";
            }
        };
        $output = $@ . $output if $@;
    }

    open( my $out, $output_file );
    my $expected = join '', <$out>;
    close $out;
    is( $output, $expected, $case );

    next unless $tree;

    my $filter = $tree->to_filter;
    $parser = new OPTIMADE::Filter::Parser;
    my $tree_now = $parser->parse_string( $filter );
    Compare( $tree, $tree_now ) || print "Roundtrip NOT passed\n";
}
