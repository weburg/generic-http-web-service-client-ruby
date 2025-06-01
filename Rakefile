require 'rake/testtask'

task default: "test"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/unit/*test.rb']
  t.verbose = true
end

Rake::TestTask.new("verify") do |t|
  t.libs << "test"
  t.test_files = FileList['test/integration/*test.rb']
  t.verbose = true
end