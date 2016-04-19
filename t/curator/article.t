=head1 NAME

t/curator/article.t

=head1 DESCRIPTION

This test makes sure the curator article object works as expected.

Use IO::Scalar to simulate a file handle. Test that articles are correctly loaded.

=cut

use strictures;
use Test::More tests => 1;
use Test::Differences;
use IO::Scalar;

use App::Curator::Article;


my $text = <<EOF;
---
title: "This is a title"
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
    list => ['list entry', 'more list'],
  },
  body => "This is article text\nhas multiple lines.",
);

sub TH {
  my ($tag, $text, %e) = @_;
    subtest $tag => sub {
    my $F = IO::Scalar->new(\$text);
    my $article = App::Curator::Article->new(path=>'n/a', _HANDLE=>$F);
    eq_or_diff($article->metadata, $e{metadata});
    eq_or_diff($article->body, $e{body});
  }
}
