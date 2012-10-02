
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  "build_requires" => {
    "Module::Build" => "0.3601"
  },
  "configure_requires" => {
    "Module::Build" => "0.3601"
  },
  "dist_abstract" => "Create your own Task-BeLike-\$AUTHOR-Favorited distribution",
  "dist_author" => [
    "Steven Haryanto <stevenharyanto\@gmail.com>"
  ],
  "dist_name" => "Dist-Create-TaskBeLikeFavorited",
  "dist_version" => "0.03",
  "license" => "perl",
  "module_name" => "Dist::Create::TaskBeLikeFavorited",
  "recommends" => {},
  "recursive_test_files" => 1,
  "requires" => {
    "File::Slurp" => 0,
    "File::chdir" => 0,
    "LWP::Simple" => 0,
    "Log::Any" => 0,
    "Mojo::DOM" => 0,
    "Perinci::CmdLine" => 0,
    "Rinci" => "v1.1.31",
    "perl" => "5.010001"
  },
  "script_files" => [
    "bin/create-task-belike-favorited-dist",
    "bin/update-task-belike-favorited-dist"
  ]
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
