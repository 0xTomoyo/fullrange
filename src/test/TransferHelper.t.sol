// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {TransferHelper} from "../libraries/TransferHelper.sol";

contract MockTransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) external {
        TransferHelper.safeApprove(token, to, value);
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) external {
        TransferHelper.safeTransfer(token, to, value);
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) external {
        TransferHelper.safeTransferFrom(token, from, to, value);
    }

    function safeTransferETH(address to, uint256 value) external {
        TransferHelper.safeTransferETH(to, value);
    }
}

contract MockERC20Compliant {
    bool public success;
    bool public shouldRevert;

    function setup(bool success_, bool shouldRevert_) external {
        success = success_;
        shouldRevert = shouldRevert_;
    }

    function transfer(address, uint256) external view returns (bool) {
        require(!shouldRevert, "REVERT");
        return success;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external view returns (bool) {
        require(!shouldRevert, "REVERT");
        return success;
    }

    function approve(address, uint256) external view returns (bool) {
        require(!shouldRevert, "REVERT");
        return success;
    }
}

contract MockERC20Noncompliant {
    bool public shouldRevert;

    function setup(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    function transfer(address, uint256) external view {
        require(!shouldRevert);
    }

    function transferFrom(
        address,
        address,
        uint256
    ) external view {
        require(!shouldRevert);
    }

    function approve(address, uint256) external view {
        require(!shouldRevert);
    }
}

contract MockFallback {
    bool public shouldRevert;

    function setup(bool shouldRevert_) external {
        shouldRevert = shouldRevert_;
    }

    receive() external payable {
        require(!shouldRevert);
    }

    function withdraw() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}

contract TransferHelperTest is DSTest {
    MockTransferHelper transferHelper;
    MockERC20Compliant compliant;
    MockERC20Noncompliant noncompliant;
    MockFallback mockFallback;

    function setUp() public {
        transferHelper = new MockTransferHelper();
        compliant = new MockERC20Compliant();
        noncompliant = new MockERC20Noncompliant();
        mockFallback = new MockFallback();
    }

    function testSafeApprove() public {
        compliant.setup(true, false);
        TransferHelper.safeApprove(address(compliant), address(0), type(uint256).max);

        compliant.setup(false, false);
        try transferHelper.safeApprove(address(compliant), address(0), type(uint256).max) {
            fail();
        } catch {}

        compliant.setup(false, true);
        try transferHelper.safeApprove(address(compliant), address(0), type(uint256).max) {
            fail();
        } catch {}

        noncompliant.setup(false);
        TransferHelper.safeApprove(address(noncompliant), address(0), type(uint256).max);

        noncompliant.setup(true);
        try transferHelper.safeApprove(address(noncompliant), address(0), type(uint256).max) {
            fail();
        } catch {}
    }

    function testSafeTransfer() public {
        compliant.setup(true, false);
        TransferHelper.safeTransfer(address(compliant), address(0), type(uint256).max);

        compliant.setup(false, false);
        try transferHelper.safeTransfer(address(compliant), address(0), type(uint256).max) {
            fail();
        } catch {}

        compliant.setup(false, true);
        try transferHelper.safeTransfer(address(compliant), address(0), type(uint256).max) {
            fail();
        } catch {}

        noncompliant.setup(false);
        TransferHelper.safeTransfer(address(noncompliant), address(0), type(uint256).max);

        noncompliant.setup(true);
        try transferHelper.safeTransfer(address(noncompliant), address(0), type(uint256).max) {
            fail();
        } catch {}
    }

    function testSafeTransferFrom() public {
        compliant.setup(true, false);
        TransferHelper.safeTransferFrom(address(compliant), address(0), address(0), type(uint256).max);

        compliant.setup(false, false);
        try transferHelper.safeTransferFrom(address(compliant), address(0), address(0), type(uint256).max) {
            fail();
        } catch {}

        compliant.setup(false, true);
        try transferHelper.safeTransferFrom(address(compliant), address(0), address(0), type(uint256).max) {
            fail();
        } catch {}

        noncompliant.setup(false);
        TransferHelper.safeTransferFrom(address(noncompliant), address(0), address(0), type(uint256).max);

        noncompliant.setup(true);
        try transferHelper.safeTransferFrom(address(noncompliant), address(0), address(0), type(uint256).max) {
            fail();
        } catch {}
    }

    function testSafeTransferETH() public {
        mockFallback.setup(false);
        TransferHelper.safeTransferETH(address(mockFallback), 0);

        mockFallback.setup(true);
        try transferHelper.safeTransferETH(address(mockFallback), 0) {
            fail();
        } catch Error(string memory error) {
            assertEq(error, "STE");
        }
    }
}
