use strict;
use warnings;
use Test::More;
use v5.10.1;

use App::Run;

our $VERSION = 3;

my $run = App::Run->new( App1->new );
is $run->version, 1, 'version from package without VERSION method';

$run = App::Run->new( App2->new );
is $run->version, 2, 'version from package with VERSION method';

$run = App::Run->new( sub { } );
is $run->version, 3, 'version from calller package';

done_testing;

package App1;
BEGIN { our $VERSION=1; };
sub new { bless {}, shift };
sub run { };

package App2;
our $VERSION=1;
sub new { bless {}, shift };
sub run { };
sub VERSION { 2 };
