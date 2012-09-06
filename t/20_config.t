use strict;
use warnings;
use Test::More;
use v5.10.1;

use App::Run;
use File::Temp;
use Config::Tiny; # for INI files

my $fh = File::Temp->new(SUFFIX => '.ini');

my ($exp_options,$exp_args)=({},[]);
my $app = sub {
	my ($options, @args) = @_;
	is_deeply $options, $exp_options, 'got options';
	is_deeply \@args, $exp_args, 'got args';
};

say $fh "foo=bar\n[doz]\nbaz=1";
close $fh;

my $run = App::Run->new($app);
$exp_options = { foo => "bar", doz => { baz => 1 } };
$run->load_config( $fh->filename );
$run->run;

done_testing;
