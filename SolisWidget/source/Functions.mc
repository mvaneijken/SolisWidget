import Toybox.Lang;

class Conversion {

    function StringToByteArray(plain_text) {
        return StringUtil.convertEncodedString(plain_text, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function ByteArrayToHexString(byte_array) {
        return StringUtil.convertEncodedString(byte_array, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function HexToString(hex) {
        return StringUtil.convertEncodedString(hex, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_HEX,
            :toRepresentation =>  StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function ByteArrayToBase64String(byte_array) {
        return StringUtil.convertEncodedString(byte_array, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function Base64StringToString(string) {
        return StringUtil.convertEncodedString(string, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function StringToBase64String(string) {
        return StringUtil.convertEncodedString(string, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        });
    }

    function Utf8ArrayToString(utf8Array) {
        return StringUtil.utf8ArrayToString(utf8Array);
    }
}

class Hash {

    function NewSha256HashObject() as Object {
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA256
        });
    }

    function NewSha1HashObject() as Object{
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_SHA1
        });
    }

    function NewSha256HashBasedMessageAuthenticationCodeObject(key as ByteArray) as Object{
        return new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_SHA256,
            :key => key
        });
    }

    function NewSha1HashBasedMessageAuthenticationCodeObject(key as ByteArray) as Object{
        return new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_SHA1,
            :key => key
        });
    }

    function NewMd5HashBasedMessageAuthenticationCodeObject(key as ByteArray) as Object{
        return new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_MD5,
            :key => key
        });
    }

    function NewMd5HashObject() as Object{
        return new Cryptography.Hash({
            :algorithm => Cryptography.HASH_MD5
        });
    }


    function ComputeHash(hash, byte_array) {
        hash.update(byte_array);
        return hash.digest();
    }

    function generateSaltedSHA1(inputString, salt) {
        var concatenatedString = inputString + salt;

        var hash = [];
        for (var i = 0; i < 20; i++) {
            hash.add(0);
        }
        Hash.sha1(concatenatedString, hash);

        var outputHash = "";
        for (var i = 0; i < 20; i++) {
            var hex = format("%02x", hash[i]);
            outputHash += hex;
        }

        return outputHash;
    }


    // Function to perform circular left shift operation
    function rol32(value, shift) {
        return ((value << shift) | (value >> (32 - shift))) & 0xFFFFFFFF;
    }

    // Function to perform SHA1 hashing
    function sha1(input, output) {
        // Initialize variables
        var h0 = 0x67452301;
        var h1 = 0xEFCDAB89;
        var h2 = 0x98BADCFE;
        var h3 = 0x10325476;
        var h4 = 0xC3D2E1F0;

        // Pre-processing: padding the input
        var paddedInput = input + ((0.toChar()));
        var length = paddedInput.length();
        while ((length % 64) != 56) {
            paddedInput += ((128.toChar()));
            length = paddedInput.length();
                        System.println(paddedInput);

            System.println((length % 64));
        }
        paddedInput += Conversion.ByteArrayToHexString(Conversion.StringToByteArray(paddedInput));

        // Process the input in 512-bit chunks (16 words)
        for (var i = 0; i < paddedInput.length(); i += 64) {
            var chunk = paddedInput.slice(i, i + 64);
            var words = [];

            // Break chunk into sixteen 32-bit big-endian words
            for (var j = 0; j < 64; j += 4) {
                words.add(
                    (Hash.getAsciiValue(chunk[j]) << 24) |
                    (Hash.getAsciiValue(chunk[j + 1]) << 16) |
                    (Hash.getAsciiValue(chunk[j + 2]) << 8) |
                    Hash.getAsciiValue(chunk[j + 3])
                );
            }

            // Extend the sixteen 32-bit words into eighty 32-bit words
            for (var j = 16; j < 80; j++) {
                words[j] = Hash.rol32((words[j - 3] ^ words[j - 8] ^ words[j - 14] ^ words[j - 16]), 1);
            }

            // Initialize hash value for this chunk
            var a = h0;
            var b = h1;
            var c = h2;
            var d = h3;
            var e = h4;

            // Main loop
            for (var j = 0; j < 80; j++) {
                var f, k;
                if (j < 20) {
                    f = (b & c) | ((~b) & d);
                    k = 0x5A827999;
                } else if (j < 40) {
                    f = b ^ c ^ d;
                    k = 0x6ED9EBA1;
                } else if (j < 60) {
                    f = (b & c) | (b & d) | (c & d);
                    k = 0x8F1BBCDC;
                } else {
                    f = b ^ c ^ d;
                    k = 0xCA62C1D6;
                }

                var temp = rol32(a, 5) + f + e + k + words[j];
                e = d;
                d = c;
                c = rol32(b, 30);
                b = a;
                a = temp;
            }

            // Add the hash of this chunk to the result so far
            h0 = (h0 + a) & 0xFFFFFFFF;
            h1 = (h1 + b) & 0xFFFFFFFF;
            h2 = (h2 + c) & 0xFFFFFFFF;
            h3 = (h3 + d) & 0xFFFFFFFF;
            h4 = (h4 + e) & 0xFFFFFFFF;
        }

        // Produce the final hash value (big-endian)
        output[0] = (h0 >> 24) & 0xFF;
        output[1] = (h0 >> 16) & 0xFF;
        output[2] = (h0 >> 8) & 0xFF;
        output[3] = h0 & 0xFF;
        output[4] = (h1 >> 24) & 0xFF;
        output[5] = (h1 >> 16) & 0xFF;
        output[6] = (h1 >> 8) & 0xFF;
        output[7] = h1 & 0xFF;
        output[8] = (h2 >> 24) & 0xFF;
        output[9] = (h2 >> 16) & 0xFF;
        output[10] = (h2 >> 8) & 0xFF;
        output[11] = h2 & 0xFF;
        output[12] = (h3 >> 24) & 0xFF;
        output[13] = (h3 >> 16) & 0xFF;
        output[14] = (h3 >> 8) & 0xFF;
        output[15] = h3 & 0xFF;
        output[16] = (h4 >> 24) & 0xFF;
        output[17] = (h4 >> 16) & 0xFF;
        output[18] = (h4 >> 8) & 0xFF;
        output[19] = h4 & 0xFF;
    }

    // Function to retrieve the ASCII value of a character
    function getAsciiValue(char) {
        return String(char)[0]; // Converts the character to a string and retrieves the ASCII value of the first character
    }


}

class DateTime {

    function GetDateUTCString() as String{

        var today = Time.Gregorian.info(Time.now(), Time.FORMAT_LONG);
        //"Fri, 26 Jul 2019 06:00:46 GMT"
        var dateString = Lang.format(
            "$1$, $2$ $3$ $4$ $5$:$6$:$7$ GMT",
            [
                today.day_of_week,
                today.day,
                today.month,
                today.year,
                today.hour,
                today.min,
                today.sec
            ]);
        return dateString;
    }

    function toMoment(string){
        //System.println(string);
        return Time.Gregorian.moment({
            :year   => string.toString().substring(0,4).toNumber(),
            :month  => string.toString().substring(5,7).toNumber(),
            :day    => string.toString().substring(8,10).toNumber(),
            :hour   => string.toString().substring(11,13).toNumber(),
            :minute => string.toString().substring(14,16).toNumber(),
            :second => string.toString().substring(17,19).toNumber()
        });
    }
}