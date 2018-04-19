require 'colorize'
require 'highline/import'
require 'pry'

PATHS = [
  # '/mnt/c/Users/Philip Ross/Downloads/Naruto; Shippūden/',
  '/mnt/c/Users/Philip Ross/Downloads/diamond no ace/',
  # '/mnt/c/Users/Philip Ross/Downloads/Accel World',
]
PATHS.each {|p| p << '/' unless p.end_with? '/'}
OPTS = {encoding: 'UTF-8'}
IGNORE_PREFIX = '[bonkai77]'
# make an array
REMOVE_SUFFIX_PREFIX = /\d{3,4}p/


def main
  paths = expand_paths
  paths.each do |path|
    episode_number_index = analyze_episode_numbers path
    rename_folder path, false
    analyze_continous
    if yesno
      rename_folder path, true
    end
  end
end

def analyze_episode_numbers(path)
  # return which
end

def yesno(default = true, prompt = 'Continue?')
  a = ''
  s = default ? '[Y/n]' : '[y/N]'
  d = default ? 'y' : 'n'
  until %w[y n].include? a
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    a = ask("#{prompt} #{s} ") {|q| q.limit = 1; q.case = :downcase}
    $VERBOSE = original_verbosity
    a = d if a.length == 0
  end
  a == 'y'
end

main

