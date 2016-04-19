package App::Curator::Article;
use strictures;
use Moo;

use App::Curator::ArticleMetaData;

has base_path => ( is => 'ro', default=>'.' );
has dir => ( is => 'ro', required=>1 );
has filename => ( is => 'ro', required=>1 );
# body and metadata are lazily loaded from a file.
# use a trick attribute, _loaded, set to 1 when the file is loaded.
# The lazy builder for _loaded loads the file and sets body and metadata.
has _loaded => ( is => 'lazy', builder => '_load');
has body => ( is => 'lazy', writer=> '_set_body');
has metadata => (
  is => 'lazy',
  writer=> '_set_metadata',
  handles => [qw(title date modified status category tags publish tag_list blog_list)],
);

sub path {
  my ($self) = @_;
  return File::Spec->catfile($self->dir, $self->filename);
}

sub _build_body {
  my ($self) = @_;
  $self->_loaded();
  $self->body();
}
sub _build_metadata {
  my ($self) = @_;
  $self->_loaded();
  $self->metadata();
}

# for testing:
has _HANDLE => (
    is => 'rw',
);
sub _open {
  my ($self) = @_;
  my $path = File::Spec->catfile($self->base_path, $self->dir, $self->filename);
  open(my $F, "<$path") || die "Failed to open $path; $!\n";
  return $F;
}
sub _load {
  my ($self) = @_;
  my $marker = 0;
  my (@fm, @body);
  my $F = $self->_HANDLE || $self->_open();
  while (my $line = <$F>) {
    chomp($line);
    if ($line =~ m/^---\s*$/) {
      if ($marker > 1) {
        # in body - the marker is part of the text.
      } elsif ($marker) {
        # in frontmatter - move to body
        $marker++;
        next;
      } else {
        # not in frontmatter yet? - move to frontmatter.
        # If want to ignore missing ---, we can just remove the next and make
        # this part of the frontmatter.
        $marker++;
        next;
      }
    }
    if ($marker > 1) {
      push @body, $line;
    } elsif ($marker) {
      push @fm, $line;
    }
  }
  close $F;
  my $yaml = join("\n", @fm);
  my $metadata;
  eval {
    $metadata = App::Curator::ArticleMetaData->new($yaml);
  };
  if ($@) {
    my $msg = $@;
    if ($msg =~ m/Missing required arguments: (\w+) at/) {
      $msg = sprintf("no '%s' in frontmatter: %s", $1, $self->path);
    }
    die "$msg\n";
  }
  my $body = join("\n", @body);
  $self->_set_metadata($metadata);
  $self->_set_body($body);
  return 1;
}

sub publish_to {
  my ($self, $blog_name) = @_;
  for my $name ($self->metadata->publish) {
    if ($name eq $blog_name) { return 1; }
  }
  return 0;
}

1;

=head1 NAME

App::Curator::Article - Curated Article

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

This module (lazily) loads an article and its metadata.

    use App::Curator::Article;

    my $article = App::Curator->new(path=>$path);
    $list = $article->metadata->{tags};

=head1 SUBROUTINES/METHODS

=head2 new

Build a new article object. Don't read the file or load the metadata yet.

=head2 metadata

Return the article metdata as a hash.

=head1 AUTHOR

Tim Woodcock, C<< <tim at 0th.ca> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-curator at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Curator>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Curator


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Curator>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Curator>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/App-Curator>

=item * Search CPAN

L<http://search.cpan.org/dist/App-Curator/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 Tim Woodcock.

This program is distributed under the MIT (X11) License:
L<http://www.opensource.org/licenses/mit-license.php>

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.


=cut

1; # End of App::Curator::Article
