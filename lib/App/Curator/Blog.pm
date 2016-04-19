package App::Curator::Blog;
use strictures;
use Moo;

has name => ( is => 'ro', required => 1, );
has engine => ( is => 'ro', required => 1, );
has domain => ( is => 'ro', required => 1, );
has publish_path => ( is => 'ro', required => 1, );
has template => ( is => 'ro', required => 1, );

sub as_string {
  my ($self) = @_;
  my $rv = $self->name . "\n";
  $rv .= "  domain: " . $self->domain . "\n";
  $rv .= "  using engine: " . $self->engine . "\n";
  $rv .= "  path: " . $self->publish_path . "\n";
}

1;
