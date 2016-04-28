use Test::More tests => 7;
=head1 NAME

t/curator/article_metadata.t

=head1 DESCRIPTION

This test makes sure the article metadata object works as expected.

=cut

use strictures;
use Test::Differences;
use IO::Scalar;

use App::Curator::ArticleMetaData;

my $input = "";
my %expected;


TH("empty", $input, \%expected, qr/^Missing required arguments/);

{
$input = <<EOF;
---
title: my title
date: 2016-04-01 20:20
modified: 2016-04-01 20:20
status: draft
notes: Some text goes here
category: this/is/the/category
tags: these, are, tags
publish: blog1, blog2, blog3
summary: This is summary text.
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   modified => '2016-04-01 20:20',
   status => 'draft',
   notes => 'Some text goes here',
   category => 'this/is/the/category',
   tags => [qw(these are tags)],
   publish => [qw(blog1 blog2 blog3)],
   summary => "This is summary text.",
);
TH("normal data", $input, \%expected, undef);
}

$input = <<EOF;
---
Title: my title
Date: 2016-04-01 20:20
Modified: 2016-04-01 20:20
Status: draft
Notes: Some text goes here
Category: this/is/the/category
Tags: these, are, tags
Publish: blog1, blog2, blog3
Summary: This is summary text.
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   modified => '2016-04-01 20:20',
   status => 'draft',
   notes => 'Some text goes here',
   category => 'this/is/the/category',
   tags => [qw(these are tags)],
   publish => [qw(blog1 blog2 blog3)],
   summary => "This is summary text.",
);
TH("capitalized yaml keys", $input, \%expected, undef);

$input = <<EOF;
---
title: my title
created: 2016-04-01 20:20
notes: Some text goes here
categories:
   - this.is.the.category
tag: these, are, tags
publish: blog1, blog2, blog3
summary: This is summary text.
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   status => 'draft',
   notes => 'Some text goes here',
   category => 'this/is/the/category',
   tags => [qw(these are tags)],
   publish => [qw(blog1 blog2 blog3)],
   summary => "This is summary text.",
);
TH("translations: #1", $input, \%expected, undef);
{
$input = <<EOF;
---
title: my title
date: 2016-04-01 20:20
modified: 2016-04-01 20:20
public: true
categories: this/is/the/category
tags:
   - these
   - are
   - tags
publish: [blog1, blog2, blog3]
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   modified => '2016-04-01 20:20',
   status => 'published',
   category => 'this/is/the/category',
   tags => [qw(these are tags)],
   publish => [qw(blog1 blog2 blog3)],
);
# "public=true" becomes  "status = published"
# "categories: value" becomes "category: value"
# tags passed as an array
# publish list as an array.
TH("translations: #2", $input, \%expected, undef);
}

{
$input = <<EOF;
---
title: my title
date: 2016-04-01 20:20
public: false
category: this/is/the/category
extra:
   stuff:
      - finds its
      - own way
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   status => 'draft',
   category => 'this/is/the/category',
   tags => [],
   publish => [],
   extra => { stuff => ['finds its', 'own way']}
);
# "public=false" becomes "status=draft"
TH("translations #3", $input, \%expected, undef);
}

{
$input = <<EOF;
---
title: my title
date: 2016-04-01 20:20
modified: 2016-04-01 20:20
status: draft
notes: Some text goes here
categories:
   - category1
   - category2
tags: these, are, tags
publish: blog1, blog2, blog3
summary: This is summary text.
EOF

%expected = (
   title => 'my title',
   date => '2016-04-01 20:20',
   modified => '2016-04-01 20:20',
   status => 'draft',
   notes => 'Some text goes here',
   category => 'this/is/the/category',
   tags => [qw(these are tags)],
   publish => [qw(blog1 blog2 blog3)],
   summary => "This is summary text.",
);
TH("multiple categories", $input, \%expected, qr/^multiple categories found$/);
}

sub TH {
  my ($tag, $input, $expected, $exception) = @_;
    $tag = sprintf("%s [%d]", $tag, (caller(0))[2]);
    subtest $tag => sub {
      plan tests => 1;
      my $metadata;
      eval { $metadata = App::Curator::ArticleMetaData->new($input); };
      if ($@) {
         my $msg = $@;
         if ($exception) {
            like($msg, $exception, "raised exception")
         } else {
            ok(0) || diag("Unexpected die:\n$msg")
         }
      } else {
         eq_or_diff($metadata->as_hash, $expected);
      }
  }
}
