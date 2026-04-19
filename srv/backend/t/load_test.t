use strict;
use warnings;
use lib 'lib';
use Wordwonk;
use Test::More;

warn "Attempting to create Wordwonk app...\n";
my $app = Wordwonk->new;
warn "App created.\n";

warn "Attempting to call startup...\n";
$app->startup;
warn "Startup finished.\n";

ok(1, "Got here");
done_testing();

