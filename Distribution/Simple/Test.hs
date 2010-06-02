-----------------------------------------------------------------------------
-- |
-- Module      :  Distribution.Simple.Test
-- Copyright   :  Thomas Tuegel 2010
--
-- Maintainer  :  cabal-devel@haskell.org
-- Portability :  portable
--
-- This is the entry point into testing a built package. Performs the
-- \"@.\/setup test@\" action. It runs testsuites designated in the package
-- description and reports on the results.

{- All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.

    * Neither the name of Isaac Jones nor the names of other
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. -}

module Distribution.Simple.Test ( test ) where

import Distribution.PackageDescription
        ( PackageDescription(..), Testsuite(..), TestType(..)
        , hasTests, matches )
import Distribution.Simple.LocalBuildInfo ( LocalBuildInfo(..) )
import Distribution.Simple.BuildPaths ( exeExtension )
import Distribution.Simple.Setup ( TestFlags(..), fromFlag )
import Distribution.Simple.Utils
import Distribution.Text
import Distribution.Verbosity ( Verbosity, silent )
import Distribution.Version ( anyVersion, thisVersion, Version(..) )

import Control.Monad ( unless )
import System.FilePath ( (</>), (<.>) )
import System.Exit ( ExitCode(..) )

-- |Perform the \"@.\/setup test@\" action.
test :: PackageDescription  -- ^information from the .cabal file
     -> LocalBuildInfo      -- ^information from the configure step
     -> TestFlags           -- ^flags sent to test
     -> IO ()
test pkg_descr lbi flags = do
    let verbosity = fromFlag $ testVerbosity flags
        exeTestType = (ExeTest $ thisVersion $ Version [1] [])
        doTest t =
            if testType t `matches` exeTestType
                then doExeTest t
                else do
                    _ <- die $ "No support for running test type: " ++
                               show (disp $ testType t)
                    return False
        doExeTest t = do
            (out, _, exit) <- rawSystemStdInOut silent exe []
                                                Nothing False
            case exit of
                ExitSuccess -> do
                    notice verbosity $ "Testsuite " ++ testName t ++
                                       " successful."
                    doOutput info out
                    return True
                ExitFailure code -> do
                    notice verbosity $ "Testsuite " ++ testName t ++
                                       " failure with exit code " ++
                                       show code ++ "!"
                    doOutput notice out
                    return False
            where exe = buildDir lbi </> testName t </>
                        testName t <.> exeExtension
                  doOutput :: (Verbosity -> String -> IO ())
                           -> String -> IO ()
                  doOutput f o = if null o then return () else
                    f verbosity $ "Testsuite " ++ testName t ++
                                " output:\n" ++ o
    unless (hasTests pkg_descr) $ notice verbosity
            "Package has no tests or was configured with tests disabled."
    results <- mapM doTest $ testsuites pkg_descr
    let successful = length $ filter id results
        total = length $ testsuites pkg_descr
    notice verbosity $ show successful ++ " of " ++ show total ++
                       " testsuites successful."