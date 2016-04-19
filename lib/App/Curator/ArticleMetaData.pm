package App::Curator::ArticleMetaData;
=head1 NAME

App::Curator::ArticleMetaData - Encapsulate article metadata.

=head1 SYNOPSIS

This module encapsulates the frontmatter metadata in articles. It does a simple
translation on instantiation to bring the data to canonical form.

  $meta = App::Curator::ArticleMetaData->new($yaml);
  $meta = App::Curator::ArticleMetaData->new($hash);

  $string = $meta->title;
  $date = $meta->date;
  $modified = $meta->modified;
  $status = $meta->status;
  $notes = $meta->notes;
  $category = $meta->category;
  $arrayref = $meta->tags;
  $arrayref = $meta->publish;

  %data = $meta->as_hash;
  $yaml = $meta->as_yaml;

  # less useful?
  $text = $meta->as_string;

=head1 INTERFACE

=head2 new({$yaml|%params})

Create a new metadata instance passing either a YAML string or a hash containing
parameters.

If you pass a YAML string, we do a translation to canon.

=over

=item tags

Convert a CSV string  or single tag into a list.

=item tag

This is a typo, replace with tags attribute unless tags exists as well. If
both tag and tags exist, ignore the tag attribute.

=item categories => category

The categories column is removed and replaced with category.

The curator only accepts 1 category. If the categories attribute is present with
only 1 category, it is converted. If there are more categories, we die with
"multiple categories found".

=item public => status

If status is found, the public attribute is ignored. If there is no status,
'public: True' becomes 'status: published'. 'public: False' becomes
'status: draft'. Any other value of public is ignored.

=item status

If status is not set, it is set to 'draft'. If public is not true or false,
the article will revert to draft.

=item publish

The publish attribute is a list. CSV or single values are converted to a list.

=back

=head2 as_hash

Return a hash containing the attributes set in the metadata.

=head2 as_yaml

Return the (canonical) YAML text.

=head2 as_string

Return a formatted string, not expected to be computer readable.

=cut
use strictures;
use Moo;
use YAML::XS;

sub BUILDARGS {
  if (scalar(@_) == 2) {
    my ($self, $yaml) = @_;
    my $args = YAML::XS::Load($yaml);
    $self->_translation($args);
    return $args;
  }
  return { @_ };
}
sub _translation {
  my ($self, $args) = @_;
  if (exists $args->{created}) {
    # date replaces created
    $args->{date} = $args->{created};
    delete $args->{created};
  }
  if (exists $args->{tag}){
    # replace tag with tags.
    if (!exists $args->{tags}) {
      $args->{tags} = $args->{tag};
    } # otherwise, ignore
    delete $args->{tag};
  }
  if (exists $args->{tags}) {
    # tags is a list but might be stored as a single value or CSV.
    if (!ref($args->{tags})) {
      $args->{tags} = [split(qr/\s*,\s*/, $args->{tags})];
    }
  }
  if (exists $args->{public}) {
    # ignore args{public} if there is a status attribute.
    if (!$args->{status}) {
       if ($args->{public} =~ m/true/i) {
         $args->{status} = 'published';
       } elsif ($args->{public} =~ m/false/i) {
         $args->{status} = 'draft';
       }
    }
    delete $args->{public};
  }
  if (!$args->{status}) {
    # default to status=draft.
    $args->{status} = 'draft';
  }
  if (exists $args->{categories}) {
    # caregories is not allowed - we only support 1 category per file.
    # migrate if there is only 1, abort on multiple values.
    if (ref $args->{categories}) { # array.
      if (scalar(@{ $args->{categories}}) > 1) {
        die "multiple categories found"
      } else {
        my $cat = shift @{$args->{categories}};
        $args->{category} = $cat;
      }
    } else {
      $args->{category} = $args->{categories};
    }
    delete $args->{categories};
  }
  if (exists $args->{category}) {
    # replace category.subcategory with category/subcategory.
    $args->{category} =~ s{\.}{/};
  }
  if ($args->{category} eq 'research/cms') {
    $DB::single = 1;
  }
  if (exists $args->{publish}) {
    # publish is a list of blogs to publish to.
    # might be stored as a single value or CSV.
    if (!ref($args->{publish})) {
      if ($args->{publish}) {
        $args->{publish} = [split(/\s*,\s*/, $args->{publish})];
      } else {
        delete $args->{publish};
      }
    }
  }
}

has title => ( is=>'rw', required=>1);
has date => ( is=>'rw', required=>1);
has modified => ( is=>'rw');
has status => ( is=>'rw', required=>1);
has notes => ( is=>'rw', );
has category => ( is=>'rw', required=>1);
has tags => ( is=>'ro', default=>sub {[]});
has publish => (is=>'ro', default=>sub {[]});
has summary => (is=>'ro');

sub tag_list { return @{ shift->tags || []}}
sub blog_list { return @{ shift->publish || []}}

sub as_hash {
  my ($self) = @_;
  my %rv;
  $rv{title} = $self->title if $self->title;
  $rv{date} = $self->date if $self->date;
  $rv{modified} = $self->modified if $self->modified;
  $rv{status} = $self->status if $self->status;
  $rv{notes} = $self->notes if $self->notes;
  $rv{category} = $self->category if $self->category;
  $rv{tags} = $self->tags if $self->tags;
  $rv{publish} = $self->publish if $self->publish;
  $rv{summary} = $self->summary if $self->summary;
  return %rv;
}
sub as_yaml {
  my ($self) = @_;
  return YAML::XS::Dump({$self->as_hash});
}
sub as_string {
  my ($self) = @_;
  my $rv = '';
  $rv .= sprintf("title: %s\n", $self->title) if $self->title;
  $rv .= sprintf("date: %s\n", $self->date) if $self->date;
  $rv .= sprintf("modified: %s\n", $self->modified) if $self->modified;
  $rv .= sprintf("status: %s\n", $self->status) if $self->status;
  $rv .= sprintf("notes: %s\n", $self->notes) if $self->notes;
  $rv .= sprintf("category: %s\n", $self->category) if $self->category;
  $rv .= sprintf("tags: %s\n", join(", ", @{ $self->tags })) if scalar $self->tags;
  $rv .= sprintf("publish: %s\n", join(", ", @{ $self->publish })) if scalar $self->publish;
  $rv .= sprintf("summary: %s\n", join(", ", @{ $self->summary })) if scalar $self->summary;
}
=head1 AUTHOR

Tim Woodcock, C<< <tim at 0th.ca> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-app-curator at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=App-Curator>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::Curator::ArticleMetaData


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


1;
