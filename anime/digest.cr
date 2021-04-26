require "digest"

fun lib_init : Void
  GC.init
  argv = ["fake-program_name".to_unsafe].to_unsafe
  LibCrystalMain.__crystal_main(1, argv)
end

alias StringBytes = UInt8*

fun is_release : Bool
    {{ flag?(:release) }}
end

fun source_sha256 : StringBytes
    {{ system("crystal eval 'require \"digest\"; print Digest::SHA256.new().file(\"#{__FILE__}\").final.to_slice.hexstring'").stringify }}.to_unsafe
end

fun sha256(path_ptr : StringBytes) : StringBytes
    Digest::SHA256.new().file(String.new(path_ptr)).final.to_slice.hexstring.to_unsafe
end

fun print_crystal(pointer : StringBytes, z : Int32) : StringBytes
    arg = String.new(pointer)
    str = String::Builder.new()
    z.times do
        str << "This is a test: #{arg}"
    end
    str.to_s.to_unsafe
end

fun add(x : Int32, y : Int32, z : Int32) : Int32
    a = 0
    z.times do
        a = x + y
    end
    a
end
