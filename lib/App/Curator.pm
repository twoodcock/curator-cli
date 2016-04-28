package App::Curator;
=head1 NAME

App::Curator - Curate a set of blog posts; publish to blog by configuration.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

This module provides the API used by the curator CLI.
It assembles the articles and implements the functions
required to deliver content to the user.

   $app = App::Curator->new(config_file => $path);

   # article routes:
   @list = $app->article_list();
   # filter for blog and/or status:
   @list = $app->article_list(blog=>$name);
   @list = $app->article_list(status=>$status);
   @list = $app->article_list(blog=>$name, status=>$status);

   $article = $app->article($route);

=head1 DESCRIPTION

The curator app curates a set of blog posts/articles and publishes them to their
configured locations. The collection config file defines a set of blogs. Each
post in the collection may specify 1 or more blogs for publishing.

=head1 CONFIGURATION FILE SYNTAX

The configuration is a YAML file containing data about the blog source to be
curated.

The following example shows a configuration file with 1 blog, to be rendered
using the template peican/post.tt2 and rendered into files in the given
publish path.

  source: /home/curator/articles/
  template_path: /home/curator/templates
  blogs:
    test-site:
      engine: pelican
      domain: woodcock.ca
      publish_path: /home/tim/Projects/pelican/test.site/curator-content/
      template: pelican/post.tt2

=head1 SUBROUTINES/METHODS

=head2 new(config_file => $path)

Create a new app object. You must pass the path to the configuration file.

=head2 blog_names

Return the list of blog names.

=head2 blog($name)

Return the blog object for the given name. This refers to an entry in the
configuration file.

=head2 article_list([blog=>$name, status=>$status])

Return the list of relative paths to the articles in the source. The list can be
filtered on blog or status.

=head2 article($relpath)

Return the article object for the given relative path.

=head2 publish_article($article)

Publish this article to all the blogs it is posted to.

=cut

use 5.006;
use strictures;
use Moo;

use App::Curator::Blog;
use App::Curator::Article;

use File::Spec;
use YAML::XS;
use File::Find;

our $FIND = qr{\.(md|markdown|rst)$}i;

has config_file => (
  is => 'ro',
  required => 1,
);

sub BUILD {
  my ($self) = @_;
  my $path = $self->config_file();
  my $data = YAML::XS::LoadFile($path);
  # set the source directory. This will be search for articles (posts).
  $self->_source($data->{source});
  if (!$self->_source()) {
    die "source not defined in the configuration file.\n"
  }
  my (%blog, %article);
  # Create blog objects for each blog entry in the configuration file.
  for my $key (keys %{ $data->{blogs} || {}}) {
    $blog{$key} = App::Curator::Blog->new(name=>$key, %{ $data->{blogs}->{$key} });
  }
  $self->_blogs(\%blog);

  if (exists $data->{template_path} && !$self->template_path) {
    # allow the configuration file to specify the path to templates that will be
    # used to render content for the blogs.
    $self->template_path($data->{template_path});
  }

  find(sub {
    my $short = $_;
    my $dir = $File::Find::dir;
    my $name = $File::Find::name;
    if ($name !~ m/$FIND/) {
      return 0;
    }
    if (-f $name) {
      my $tmp = $name;
      my $source = $self->_source;
      if ($source !~ m{/$}) {
        $source .= "/";
      }
      my $source_re = quotemeta($source);
      $tmp =~ s/^$source_re//;
      my ($dir, $file) = $tmp =~ m{^(.*)/([^/]*)$};
      eval {
        $article{$tmp} = App::Curator::Article->new(base_path => $source, dir => $dir, filename=>$file);
      };
      $_ = $@;
      if ($_) {
        warn "article died: $tmp; $path; $_";
      }
    }
  }, $self->_source());
  $self->_articles(\%article);
}

has _source => (
  is => 'rw',
);

sub blog { my ($self, $key) = @_; return $self->_blogs()->{$key}; }
sub blog_names {my ($self) = @_;  return sort keys %{ $self->_blogs() }; }
has _blogs => (
  is => 'rw',
  default => sub {{}},
);

sub article { my ($self, $key) = @_; return $self->_articles()->{$key}; }
sub article_list {
   my ($self, %params) = @_;
   my @rv;
   my @test;
   if (my $blog = $params{blog}) {
      # include all articles that include $blog.
      push @test, sub { my ($a) = shift; return scalar grep { $_ eq $blog } $a->blog_list };
   }
   if (my $status = $params{status}) {
      push @test, sub { my ($a) = shift; return $a->status() eq $status };
   }
   my @list = grep {
      my $route = $_;
      my $want = 1;
      for my $test (@test) {
         $want &&= $test->($self->_articles()->{$route});
      }
      $want;
   } keys %{ $self->_articles()};
   return sort @list;
}
has _articles => (
  is => 'rw',
  default => sub { return {};},
);

has template_path => (
  is => 'rw',
  default => './templates',
  # strictly speaking, we should reset the renderer when this is changed:
  # trigger => sub { shift->renderer(undef); }
);

has renderer => (
  is => 'lazy',
);

sub _build_renderer {
  my ($self) = @_;
  require Template;
  my $config = {
    INCLUDE_PATH => $self->template_path,
  };
  return Template->new($config);
}

sub publish_article {
  my ($self, $article, %params) = @_;
  my $tt = $self->renderer();
  for my $blog_name (@{$article->metadata->publish }){
    next if (exists $params{blog} && $blog_name ne $params{blog});
    my $blog = $self->blog($blog_name);
    if (!$blog) {
      die "failed to locate blog $blog_name for article"
    }
    # we need untainting somewhere.
    my $target_dir = File::Spec->catfile($blog->publish_path, $article->dir);
    my $target_path = File::Spec->catfile($target_dir, $article->filename);
    if ($params{tracker}{$blog_name}{filenames}{$article->filename}) {
      warn "writing  another article with the file name: ". $article->filename . "\n";
    }
    if ($params{tracker}{$blog_name}{paths}{$target_path}) {
      die "ABORT: found a second article with the path $target_path\n";
    }

    # we have to make sure directories exist.
    require File::Path;
    my $err;
    File::Path::make_path($target_dir, {error=>\$err});
    if (@$err) {
      my @msg = ("Fatal error trying to create $target_dir:");
      for my $err (@$err) {
        my ($file, $msg) = %$err;
        if ($file){
          push @msg, "$file: $msg";
        } else {
          push @msg, "$msg";
        }
      }
      die join("\n", @msg);
    }

    # we have to render content.
    my $content;
    my $rv = $tt->process($blog->template, {article => $article}, \$content);
    if (!$rv) {
      die "failed to render " . $article->path() . ": " . $tt->error() . "\n";
    }

    open(my $F, ">$target_path")
      || die "failed to open " . $article->path() . ": $!\n";
    print $F $content;
    close $F;

    $params{tracker}{$blog_name}{filenames}{$article->filename} = 1;
    $params{tracker}{$blog_name}{paths}{$target_path} = 1;
  }
}

sub publish {
  my ($self, %params) = @_;
  # we need to track articles we have written so we can report if we try to
  # overwrite something.
  my %tracker;
  my @errors;
  my %article_params = ( tracker => \%tracker, );
  if ($params{blog}) {
    $article_params{blog} = $params{blog};
  }
  my $list_method;
  if ($params{article}) {
    $list_method = sub { return ($params{article})};
  } else {
    $list_method = sub { return $self->article_list() };
  }

  for my $name ($list_method->()) {
    eval {
      my $article = $self->article($name);
      if (!$article) {
        die "Failed to publish $name: article not found.\n";
      }
      $self->publish_article($article, %article_params);
    };
    if ($@) {
      push @errors, [$name, $@];
    }
  }
  if (scalar(@errors)) {
    warn "We had problems:\n";
    for my $pair (@errors) {
      warn $pair->[0]."\n";
      $pair->[1] =~ s/^/|  /msg;
      warn $pair->[1] . "\n";
    }
  }
  my $pub_count = 0;
  for my $blog_name (keys %tracker) {
    my $count = scalar(keys(%{$tracker{$blog_name}{paths}}));
    printf("Published %d article%s to %s\n", $count, ($count==1)?'':'s', $blog_name);
    $pub_count++;
  }
  if ($pub_count == 0) {
    printf("No articles published.\n");
  }
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

1; # End of App::Curator
