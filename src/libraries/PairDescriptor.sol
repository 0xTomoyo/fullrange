// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IFullRange} from "../interfaces/IFullRange.sol";

library PairDescriptor {
    struct DecimalStringParams {
        // significant figures of decimal
        uint256 sigfigs;
        // length of decimal string
        uint8 bufferLength;
        // ending index for significant figures (funtion works backwards when copying sigfigs)
        uint8 sigfigIndex;
        // index of decimal place (0 if no decimal)
        uint8 decimalIndex;
        // start index for trailing/leading 0's for very small/large numbers
        uint8 zerosStartIndex;
        // end index for trailing/leading 0's for very small/large numbers
        uint8 zerosEndIndex;
        // true if decimal number is less than one
        bool isLessThanOne;
        // true if string should include "%"
        bool isPercent;
    }

    function constructSymbol(address fullRange) internal view returns (string memory) {
        IUniswapV3Pool pool = IUniswapV3Pool(IFullRange(fullRange).getPool(address(this)));
        return
            string(
                abi.encodePacked(
                    "UNI-V3-",
                    tokenSymbol(pool.token0()),
                    "/",
                    tokenSymbol(pool.token1()),
                    "-",
                    feeToPercentString(pool.fee())
                )
            );
    }

    function constructName(address fullRange) internal view returns (string memory) {
        IUniswapV3Pool pool = IUniswapV3Pool(IFullRange(fullRange).getPool(address(this)));
        return
            string(
                abi.encodePacked(
                    "Uniswap V3 ",
                    tokenSymbol(pool.token0()),
                    "/",
                    tokenSymbol(pool.token1()),
                    " ",
                    feeToPercentString(pool.fee()),
                    " LP"
                )
            );
    }

    // attempts to extract the token symbol. if it does not implement symbol, returns a symbol derived from the address
    function tokenSymbol(address token) internal view returns (string memory) {
        // 0x95d89b41 = bytes4(keccak256("symbol()"))
        string memory symbol = callAndParseStringReturn(token, 0x95d89b41);
        if (bytes(symbol).length == 0) {
            // fallback to 6 uppercase hex of address
            return toAsciiString(token, 6);
        }
        return symbol;
    }

    function feeToPercentString(uint24 fee) internal pure returns (string memory) {
        if (fee == 0) {
            return "0%";
        }
        uint24 temp = fee;
        uint256 digits;
        uint8 numSigfigs;
        unchecked {
            while (temp != 0) {
                if (numSigfigs > 0) {
                    // count all digits preceding least significant figure
                    numSigfigs++;
                } else if (temp % 10 != 0) {
                    numSigfigs++;
                }
                digits++;
                temp /= 10;
            }
        }

        DecimalStringParams memory params;
        uint256 nZeros;
        if (digits >= 5) {
            // if decimal > 1 (5th digit is the ones place)
            uint256 decimalPlace = (digits - numSigfigs) >= 4 ? 0 : 1;
            nZeros = (digits - 5) < (numSigfigs - 1) ? 0 : (digits - 5) - (numSigfigs - 1);
            params.zerosStartIndex = numSigfigs;
            params.zerosEndIndex = uint8((params.zerosStartIndex + nZeros) - 1);
            params.sigfigIndex = uint8((params.zerosStartIndex - 1) + decimalPlace);
            params.bufferLength = uint8(nZeros + (numSigfigs + 1) + decimalPlace);
        } else {
            // else if decimal < 1
            nZeros = 5 - digits;
            params.zerosStartIndex = 2;
            params.zerosEndIndex = uint8((nZeros + params.zerosStartIndex) - 1);
            params.bufferLength = uint8(nZeros + (numSigfigs + 2));
            params.sigfigIndex = uint8((params.bufferLength) - 2);
            params.isLessThanOne = true;
        }
        params.sigfigs = fee / (10**(digits - numSigfigs));
        params.isPercent = true;
        params.decimalIndex = digits > 4 ? uint8(digits - 4) : 0;

        return generateDecimalString(params);
    }

    // converts an address to the uppercase hex string, extracting only len bytes (up to 20, multiple of 2)
    function toAsciiString(address addr, uint256 len) internal pure returns (string memory) {
        unchecked {
            require(len % 2 == 0 && len > 0 && len <= 40);

            bytes memory s = new bytes(len);
            uint256 addrNum = uint256(uint160(addr));
            for (uint256 i = 0; i < len / 2; i++) {
                // shift right and truncate all but the least significant byte to extract the byte at position 19-i
                uint8 b = uint8(addrNum >> (8 * (19 - i)));
                // first hex character is the most significant 4 bits
                uint8 hi = b >> 4;
                // second hex character is the least significant 4 bits
                uint8 lo = b - (hi << 4);
                s[2 * i] = uint8ToChar(hi);
                s[2 * i + 1] = uint8ToChar(lo);
            }
            return string(s);
        }
    }

    // calls an external view token contract method that returns a symbol or name, and parses the output into a string
    function callAndParseStringReturn(address token, bytes4 selector) private view returns (string memory) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(selector));
        // if not implemented, or returns empty data, return empty string
        if (!success || data.length == 0) {
            return "";
        }
        // bytes32 data always has length 32
        if (data.length == 32) {
            bytes32 decoded = abi.decode(data, (bytes32));
            return bytes32ToString(decoded);
        } else if (data.length > 64) {
            return abi.decode(data, (string));
        }
        return "";
    }

    function bytes32ToString(bytes32 x) private pure returns (string memory) {
        unchecked {
            bytes memory bytesString = new bytes(32);
            uint256 charCount = 0;
            for (uint256 j = 0; j < 32; j++) {
                bytes1 char = x[j];
                if (char != 0) {
                    bytesString[charCount] = char;
                    charCount++;
                }
            }
            bytes memory bytesStringTrimmed = new bytes(charCount);
            for (uint256 j = 0; j < charCount; j++) {
                bytesStringTrimmed[j] = bytesString[j];
            }
            return string(bytesStringTrimmed);
        }
    }

    // hi and lo are only 4 bits and between 0 and 16
    // this method converts those values to the unicode/ascii code point for the hex representation
    // uses upper case for the characters
    function uint8ToChar(uint8 b) private pure returns (bytes1 c) {
        unchecked {
            if (b < 10) {
                return bytes1(b + 0x30);
            } else {
                return bytes1(b + 0x37);
            }
        }
    }

    function generateDecimalString(DecimalStringParams memory params) private pure returns (string memory) {
        unchecked {
            bytes memory buffer = new bytes(params.bufferLength);
            if (params.isPercent) {
                buffer[buffer.length - 1] = "%";
            }
            if (params.isLessThanOne) {
                buffer[0] = "0";
                buffer[1] = ".";
            }

            // add leading/trailing 0's
            for (
                uint256 zerosCursor = params.zerosStartIndex;
                zerosCursor < (params.zerosEndIndex + 1);
                zerosCursor++
            ) {
                buffer[zerosCursor] = bytes1(uint8(48));
            }
            // add sigfigs
            while (params.sigfigs > 0) {
                if (params.decimalIndex > 0 && params.sigfigIndex == params.decimalIndex) {
                    buffer[params.sigfigIndex--] = ".";
                }
                buffer[params.sigfigIndex--] = bytes1(uint8(48 + (params.sigfigs % 10)));
                params.sigfigs /= 10;
            }
            return string(buffer);
        }
    }
}
