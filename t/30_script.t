use strict;
use warnings;
use Test::More;
use v5.10.1;

BEGIN { @ARGV = qw(foo bar=1 doz) };

use App::Run 'script';

is_deeply \@ARGV, [qw(foo doz)], 'parsed @ARGV on use';
is_deeply $OPTS, { bar => 1 }, 'set $OPTS on use';

done_testing;
