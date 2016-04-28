=head1 NAME

t/curator/article.t

=head1 DESCRIPTION

This test makes sure the article object works as expected.

Use IO::Scalar to simulate a file handle. Test that articles are correctly loaded.

Metadata is tested in t/curator/article_metadata.t. We do not have to test how
the metadata section is interpreted.

=cut

use strictures;
use Test::More tests => 1;
use Test::Differences;
use IO::Scalar;

use App::Curator::Article;


my $text = <<EOF;
---
title: "This is a title"
date: 2016-04-10
category: whatever
list:
  - list entry
  - more list
---
This is article text
has multiple lines.
EOF
TH('simple, random metadata',
  $text,
  metadata => {
    title => "This is a title",
    date => '2016-04-10',
    status => 'draft', # default
    category => 'whatever',
    publish => [],
    tags => [],
    list => ['list entry', 'more list'],
  },
  body => "This is article text\nhas multiple lines.",
);

sub TH {
  my ($tag, $text, %e) = @_;
    subtest $tag => sub {
    my $F = IO::Scalar->new(\$text);
    my $article = App::Curator::Article->new(filename=>'n/a', dir=>'n/a', _HANDLE=>$F);
    eq_or_diff($article->metadata->as_hash(), $e{metadata});
    eq_or_diff($article->body, $e{body});
  }
}
