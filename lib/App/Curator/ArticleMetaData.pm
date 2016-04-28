package App::Curator::ArticleMetaData;
=head1 NAME

App::Curator::ArticleMetaData - Encapsulate article metadata.

=head1 SYNOPSIS

This module encapsulates the frontmatter metadata in articles. It does a simple
translation on instantiation to bring the data to canonical form.

  $meta = App::Curator::ArticleMetaData->new($yaml);
  $meta = App::Curator::ArticleMetaData->new($hash);

  $string = $meta->title;
  $date = $meta->date   ;
  $modified = $meta->modified;
  $status = $meta->status;
  $notes = $meta->notes;
  $category = $meta->category;
  $arrayref = $meta->tags;
  $arrayref = $meta->publish;

  # data not explicitely recognized is stashed in extra:
  $ref = $meta->extra;

  # serialization functions:
  $ref = $meta->as_hash;
  $yaml = $meta->as_yaml;

=head1 DESCRIPTION

This module provides an interface to article metadata. It recognizes a set of
keys. Any keys it does not recognized will be stored in extra(). Extra data will
be restored by as_hash and as_yaml.

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

=head2 title

Set or get the title.

=head2 date

Set or get the date.

=head2 modified

Set or get the (last) modification date

=head2 status

Set or get the status. This should be draft or published.

=head2 notes

Set or get the notes string. This is used in some posts to say why the article
has draft status.

=head2 category

Set or get the article category

=head2 tags

Get the list of tags - an array reference.

=head2 publish

Get the list of publishing locations - an array reference.

=head2 summary

Set or get the summary string.

=head2 as_hash

Return a reference to a hash containing the attributes set in the metadata.

=head2 as_yaml

Return the (canonical) YAML text.

=cut
use strictures;
use Moo;
use YAML::XS;

sub BUILDARGS {
  # If exactly 2 then we have a YAML string,
  # otherwise, we have named parameteres.
  if (scalar(@_) == 2) {
    my ($self, $yaml) = @_;
    my $args;
    if ($yaml) {
      $args = YAML::XS::Load($yaml);
    } else {
      $args = {};
    }
    $self->_translation($args);
    return $args;
  }
  return { @_ };
}
sub _translation {
  my ($self, $args) = @_;
  # Mash all recognized keys to lower case.
  # Any keys we don't recognize are put into %extra, available
  # via $obj->extra->{key}, and restored, as is, in as_hash and as_yaml.
  my %extra;
  for my $key (keys %$args) {
     if ($key !~ m/title|date|modified|status|notes|category|tags|publish|summary/i) {
        $extra{$key} = $args->{$key};
        delete $args->{$key};
     }
     if ($key ne lc($key)) {
        my $newkey = lc($key);
        if (!$args->{$newkey} && $self->can($newkey)) {
           $args->{$newkey} = $args->{$key};
           delete $args->{$key};
        }
     }
  }
  # created => date unless date is specified.
  if (exists $args->{created}) {
    $args->{date} = $args->{created};
    delete $args->{created};
  }
  # tag => tags unless tags is specified.
  if (exists $args->{tag}){
    # replace tag with tags.
    if (!exists $args->{tags}) {
      $args->{tags} = $args->{tag};
    } # otherwise, ignore
    delete $args->{tag};
  }
  # tags - break into a list if we find a single CSV string.
  if (exists $args->{tags}) {
    # tags is a list but might be stored as a single value or CSV.
    if (!ref($args->{tags})) {
      $args->{tags} = [split(qr/\s*,\s*/, $args->{tags})];
    }
  }
  # "public = bool" => "status = published|draft"
  if (exists $args->{public}) {
    # ignore args{public} if there is a status attribute.
    # if the is true, set status=published, else set status=draft.
    if (!$args->{status}) {
      if ($args->{public} =~ m/true/i) {
         $args->{public} = 1;
      } elsif ($args->{public} =~ m/false/i) {
         $args->{public} = 0;
      }
      $args->{status} = ($args->{public}?'published':'draft');
    }
    delete $args->{public};
  }
  # DEFAULT status is draft.
  if (!$args->{status}) {
    # default to status=draft.
    $args->{status} = 'draft';
  }
  # categories => category.
  # raise "multiple categories found" if there are many categories.
  if (exists $args->{categories}) {
    # caregories is not allowed - we only support 1 category per file.
    # migrate if there is only 1, abort on multiple values.
    if (ref $args->{categories}) { # array.
      if (scalar(@{ $args->{categories}}) > 1) {
        die "multiple categories found\n"
      } else {
        my $cat = shift @{$args->{categories}};
        $args->{category} = $cat;
      }
    } else {
      $args->{category} = $args->{categories};
    }
    delete $args->{categories};
  }
  # "category.subcategory" => "category/subcategory"
  if (exists $args->{category}) {
    # replace category.subcategory with category/subcategory.
    $args->{category} =~ s{\.}{/}g;
  }
  # publish is a list of targets change frm CSV to list if it is not a list.
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

  # now extract all keys we don't know about and store them in the extra attribute.
  $args->{extra} = \%extra;
}

has title => ( is=>'rw', required=>1);
has date => ( is=>'rw', required=>1);
has modified => ( is=>'rw');
has status => ( is=>'rw', required=>1);
has notes => ( is=>'rw', );
has category => ( is=>'rw', required=>1);
has tags => ( is=>'ro', default=>sub {[]});
has publish => (is=>'ro', default=>sub {[]});
has extra => (is=>'ro', default=>sub {{}});
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
  my $extra = $self->extra;
  for my $key (keys %$extra) {
     $rv{$key} = $extra->{$key};
  }
  return \%rv;
}
sub as_yaml {
  my ($self) = @_;
  return YAML::XS::Dump($self->as_hash);
}
=head1 AUTHOR

Tim Woodcock, C<< <tim at 0th.ca> >>

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
