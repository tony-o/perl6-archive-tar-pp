# usage

since i know this is all you care about

## new tar
```perl6
use Archive::Tar::PP;

my $new-archive = new-tar('x.tar');

$new-archive.push('some file'); #adds file data to buffer;

$new-archive.write; #now you have some tarball
```

## crusty tar
```perl6
use Archive::Tar::PP;

my $crusty = read-tar('x.tar');

$crusty.ls; #returns files
$crusty.peek('file-name to get contents of');
#  returns Nil for dir, empty Buf for an empty file, and a Buf with the contents otherwise
```

# limitations

* doesn't keep user or group names
* stores the buffers in memory so, beware
* rewrites entire tar file every time you write, so use sparingly
