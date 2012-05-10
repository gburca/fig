require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'fig/operatingsystem'

describe 'Fig' do
  describe 'publishing/retrieval' do
    let(:publish_from_directory)  { "#{FIG_SPEC_BASE_DIRECTORY}/publish-home" }
    let(:lib_directory)           { "#{publish_from_directory}/lib" }
    let(:retrieve_directory)      { "#{FIG_SPEC_BASE_DIRECTORY}/retrieve" }

    before(:each) do
      clean_up_test_environment
      FileUtils.mkdir_p(lib_directory)
    end

    it 'retrieves resource' do
      write_file("#{lib_directory}/a-library", 'some library')
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/a-library
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
    end

    it 'retrieves resource and ignores the append statement in the updating config' do
      write_file("#{lib_directory}/a-library", 'some library')
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/a-library
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
          append FOOPATH=@/does/not/exist
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
    end

    it 'retrieves resource that is a directory' do
      write_file("#{lib_directory}/a-library", 'some library')
      # To copy the contents of a directory, instead of the directory itself,
      # use '/.' as a suffix to the directory name in 'append'.
      input = <<-END
        resource lib/a-library
        config default
          append FOOPATH=@/lib/.
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
    end

    it %q<preserves the path after '//' when copying files into your project directory while retrieving> do
      include_directory = "#{publish_from_directory}/include"
      FileUtils.mkdir_p(include_directory)
      write_file("#{include_directory}/hello.h", 'a header file')
      write_file("#{include_directory}/hello2.h", 'another header file')
      input = <<-END
        resource include/hello.h
        resource include/hello2.h
        config default
          append INCLUDE=@//include/hello.h
          append INCLUDE=@//include/hello2.h
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update', input)

      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/include/hello.h").should == 'a header file'
      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/include/hello2.h").should == 'another header file'
    end

    it 'updates without there being a copy of the package in the FIG_HOME left there from publishing' do
      include_directory = "#{publish_from_directory}/include"
      FileUtils.mkdir_p(include_directory)
      write_file("#{include_directory}/hello.h", 'a header file')
      write_file("#{include_directory}/hello2.h", 'another header file')
      input = <<-END
        resource include/hello.h
        resource include/hello2.h
        config default
          append INCLUDE=@/include/hello.h
          append INCLUDE=@/include/hello2.h
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)

      FileUtils.rm_rf(FIG_HOME)

      input = <<-END
        retrieve INCLUDE->include2/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('-u', input)

      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/hello.h").should == 'a header file'
      File.read("#{FIG_SPEC_BASE_DIRECTORY}/include2/prerequisite/hello2.h").should == 'another header file'
    end

    it 'packages multiple resources' do
      write_file("#{lib_directory}/a-library", 'some library')
      write_file("#{lib_directory}/a-library2", 'some other library')
      input = <<-END
        resource lib/a-library
        resource lib/a-library2
        config default
          append FOOPATH=@/lib/a-library
          append FOOPATH=@/lib/a-library2
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('-m', input)
      File.read("#{retrieve_directory}/prerequisite/a-library").should == 'some library'
      File.read("#{retrieve_directory}/prerequisite/a-library2").should == 'some other library'
    end

    it 'packages multiple resources with wildcards' do
      write_file("#{lib_directory}/foo.jar", 'some library')
      write_file("#{lib_directory}/bar.jar", 'some other library')
      input = <<-END
        resource **/*.jar
        config default
          append FOOPATH=@/lib/foo.jar
        end
      END
      fig('--publish prerequisite/1.2.3', input, false, false, publish_from_directory)
      input = <<-END
        retrieve FOOPATH->retrieve/[package]
        config default
          include prerequisite/1.2.3
        end
      END
      fig('--update-if-missing', input)
      File.read("#{retrieve_directory}/prerequisite/foo.jar").should == 'some library'
    end

    if Fig::OperatingSystem.unix?
      it 'can publish and retrieve dangling symlinks' do
        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        File.symlink(
          'does-not-exist', "#{publish_from_directory}/dangling-symlink"
        )
        input = <<-END
          resource dangling-symlink
          config default
            set TEST_FILE=@/dangling-symlink
          end
        END
        fig('--publish dependency/1.2.3', input, false, false, publish_from_directory)

        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        input = <<-END
          retrieve TEST_FILE->.
          config default
            include dependency/1.2.3
          end
        END
        fig('--publish dependent/1.2.3', input, false, false, publish_from_directory)

        FileUtils.rm_rf(FIG_HOME)

        File.exist?("#{FIG_SPEC_BASE_DIRECTORY}/dangling-symlink") and
          fail 'Symlink should not exist prior to using package.'

        fig('--update dependent/1.2.3 -- echo')
        File.symlink?("#{FIG_SPEC_BASE_DIRECTORY}/dangling-symlink") or
          fail 'Symlink should exist after using package.'
      end
    end

    describe 'cleanup' do
      let(:cleanup_dependency_basename) { 'from-dependency.txt' }
      let(:cleanup_dependency_file)     {
        "#{FIG_SPEC_BASE_DIRECTORY}/#{cleanup_dependency_basename}"
      }

      before(:each) do
        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        FileUtils.touch "#{publish_from_directory}/#{cleanup_dependency_basename}"
        input = <<-END
          resource #{cleanup_dependency_basename}
          config default
            set TEST_FILE=@/#{cleanup_dependency_basename}
          end
        END
        fig('--publish dependency/1.2.3', input, false, false, publish_from_directory)

        FileUtils.rm_rf(publish_from_directory)
        FileUtils.mkdir_p(publish_from_directory)

        input = <<-END
          retrieve TEST_FILE->.
          config default
            include dependency/1.2.3
          end
        END
        fig('--publish alpha/1.2.3', input, false, false, publish_from_directory)
        fig('--publish beta/1.2.3 --no-file --set set_something=so-we-have-some-content')

        File.exist?(cleanup_dependency_file) and
          fail 'File should not exist prior to using alpha.'

        fig('--update alpha/1.2.3 -- echo')
        File.exist?(cleanup_dependency_file) or
          fail 'File should exist after using alpha.'
      end

      it 'happens with --update' do
        fig('--update beta/1.2.3 -- echo')
        File.exist?(cleanup_dependency_file) and
          fail 'File should not exist after using beta.'
      end

      it 'does not happen without --update' do
        fig('beta/1.2.3 -- echo')
        File.exist?(cleanup_dependency_file) or
          fail 'File should exist after using beta.'
      end
    end

    it 'warns on unused retrieval' do
      set_up_test_environment()

      input = <<-END
        retrieve UNREFERENCED_VARIABLE->somewhere
        config default
          set WHATEVER=SOMETHING
        end
      END
      out, err, exit_code = fig('--update-if-missing', input)

      err.should =~ /UNREFERENCED_VARIABLE.*was never referenced.*retrieve UNREFERENCED_VARIABLE->somewhere.*was ignored/
    end
  end
end
