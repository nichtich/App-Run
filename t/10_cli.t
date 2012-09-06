use strict;
use warnings;
use Test::More;
use v5.10.1;

use App::Run;
use Data::Dumper;

my ($expect_args,$expect_options);
my $app = sub {
	my ($options, @args) = @_;
	is_deeply $options, $expect_options, 'got options';
	is_deeply \@args, $expect_args, 'got args';
};

my $run = App::Run->new($app, config => undef);

$expect_options = { foo => 1, bar => 'doz' };
$expect_args 	= ['x','y'];
$run->run_with_args(qw(x bar=doz foo=1 y));

$expect_options = { foo => 2, bar => 'doz' };
$expect_args 	= [];
$run->run({foo => 2});

$expect_options = { foo => 1, doz => 3, bar => 'doz' };
$expect_args 	= [1];
$run->run({ doz => 3 },1);

done_testing;
