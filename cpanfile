requires 'File::path', '2.09';
requires 'File::Spec', '3.40';
requires 'Template', '2.26';
requires 'Moo', '2.00';
requires 'YAML::XS', '0.36';

on 'test' => sub {
   requires 'Test::More', '0.98';
   requires 'IO::Scalar', '2.111';
   requires 'Test::Differences', '0.64';
}
