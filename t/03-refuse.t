use Test;
use Archive::Tar::PP;

plan 2;
my $tar = './t/tar/refuse-to-overwrite.tar';
my $writer = new-tar($tar);
$writer.push('README.md');
dies-ok { $writer.write; }, 'refuse to overwrite existing file without read-tar or :force';

ok $writer.write(:force), 'refuse to overwrite existing file without read-tar or :force';

# vim:syntax=perl6
