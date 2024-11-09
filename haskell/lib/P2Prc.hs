{-# LANGUAGE OverloadedStrings #-}

module P2Prc ( runP2Prc )
  where


import System.Exit ( ExitCode(ExitFailure) )

import System.Process
  ( readProcessWithExitCode
  , proc
  , createProcess
  , terminateProcess
  , ProcessHandle
  )

import Control.Concurrent ( threadDelay )


import qualified Data.Text as T

import qualified Data.ByteString.Lazy.Char8 as LBC8

import Data.Aeson


import Environment ( cleanEnvironment )
import Error (IOEitherError, Error(..), assignError)
import JSON


-- URGENT TASKS
--
-- TODO: setup the project as a haskell library
-- TODO: splitting code on different files and directories
-- TODO: lock cabal index
-- TODO: add Haddock documentation
--
-- TODO: P2PRC setup
  -- p2prc runtime packaging
    -- Perhaps create internal script to run P2PRC from nix flake
      -- "nix flake run ..."
      -- simplify packaging
  -- check version P2PRC: only run if version if above a certain value
  -- setup p2prc command
    -- check if p2prc command is available in environment first
    -- otherwise check folder above
--
-- TODO: publish haskell library
--
-- TODO: add use case examples (extra-source_files)



-- Module: API

runP2Prc :: IO ()
runP2Prc = do


  -- important but not urgent yet
  --
  -- TODO: Change Standard Library
  -- TODO: add GDTA syntax to data types
  -- TODO: need monad transformers to refactor the code
  --
  -- TODO: parse IO arguments;
    -- TODO: create DSL from the standard input
  --
  -- TODO: setup nix flake package
  -- TODO: add quickcheck testing (quickchecking-dynamic)



  eitherP2prcAPI <- getP2prcAPI

  case eitherP2prcAPI of
    (Right p2prcAPI) -> do
      let
        ( MkP2prAPI
          { startServer     = startServer
          , execInitConfig  = execInitConfig
          , execListServers = execListServers
          , execMapPort     = execMapPort
          }
          ) = p2prcAPI


      configValue <- execInitConfig

      -- TODO: get name of host server from config json

      print configValue
      putStrLn "\n\n\n"

      eitherStartProcessHandle <- startServer


      case eitherStartProcessHandle of
        (Right startProcessHandle) -> do

          let sleepNSecs i = threadDelay (i * 1000000)

          sleepNSecs 5

          outputStr <- execListServers
          print outputStr

          mapPortOut <- execMapPort $ MkMapPortRequest 3333 "domain"


          case mapPortOut of
            (Right v) -> print v
            (Left e)  -> print e


          -- TODO: work on looping function
          --
          -- Loop (Run replica of haskell program on different $NODES)
          --    - Start server
          --    - wait 4 seconds
          --    - Identify new node running p2prc with SSH external port exposed
          --    - SSH into machine
          --    - Use simple File transfer to setup files
          --    - Run server
          --    - Use remote machine p2prc cmd to map a port using --mp
          --    - Return back the exposed public IP and port number back to stdout


          terminateProcess startProcessHandle

        (Left err) -> print err

    (Left err) -> print err



data P2prAPI = MkP2prAPI
  { startServer       :: IOEitherError ProcessHandle
  , execInitConfig    :: IOEitherError P2prcConfig
  , execListServers   :: IOEitherError IPAdressTable
  , execMapPort       :: MapPortRequest -> IOEitherError MapPortResponse
  }


data MapPortRequest
  = MkMapPortRequest Int String


getP2prcAPI :: IOEitherError P2prAPI
getP2prcAPI = do

  cleanEnvironment

  eitherP2prcCmd <- getP2PrcCmd

  pure $ case eitherP2prcCmd of
    (Right p2prcCmd) -> let

      execProcP2PrcParser ::
        FromJSON a =>
          [CLIOpt] -> StdInput -> IOEitherError a
      execProcP2PrcParser = eitherExecProcessParser p2prcCmd
      -- TODO: GHC question, why does it scope down instead staying generic

      execProcP2Prc = eitherExecProcess p2prcCmd

      in do

      Right $ MkP2prAPI
        { startServer = spawnProcP2Prc p2prcCmd [ MkOptAtomic "--s" ]

        , execListServers =
          execProcP2PrcParser [ MkOptAtomic "--ls" ] MkEmptyStdInput

        , execMapPort =
          \ (MkMapPortRequest portNumber _) ->
            execProcP2PrcParser
              [ MkOptTuple
                ( "--mp"
                , show portNumber
                )
              -- , MkOptTuple -- TODO: add domain parameter
              --   ( "--dm"
              --   , domainName
              --   )
              ]
              MkEmptyStdInput

        , execInitConfig = do

          confInitRes <- execProcP2Prc [ MkOptAtomic "--dc" ] MkEmptyStdInput

          case confInitRes of
            (Right _) -> do

              -- TODO: get config file name dynamically

              -- TODO: change values before loading file
              let fname = "/home/xecarlox/Desktop/p2p-rendering-computation/haskell/config.json" :: FilePath


              -- TODO: read config check if file exists
              configContent <- readFile fname

              pure $ eitherErrDecode configContent

            (Left err) -> pure $ Left err

        }

    (Left err) -> Left err



-- Module: CLI

data StdInput
  = MkEmptyStdInput
  | MkStdInputVal String


instance Show StdInput where
  show MkEmptyStdInput    = ""
  show (MkStdInputVal v)  = v


data CLIOpt
  = MkEmptyOpts
  | MkOptAtomic String
  | MkOptTuple (String, String)

type CLIOptsInput = [String]
type CLICmd       = String


eitherExecProcessParser ::
  FromJSON a =>
    CLICmd -> [CLIOpt] -> StdInput -> IOEitherError a
eitherExecProcessParser p2prcCmd opts stdInput =
  do
    val <- eitherExecProcess p2prcCmd opts stdInput

    pure $ case val of
      (Right v) -> eitherErrDecode v
      (Left e)  -> Left e


eitherErrDecode ::
  FromJSON a =>
    String -> Either Error a
eitherErrDecode = eitherErrorDecode . eitherDecode . LBC8.pack


eitherExecProcess :: CLICmd -> [CLIOpt] -> StdInput -> IOEitherError String
eitherExecProcess cmd opts input =
  do
    (code, out, err) <-
      readProcessWithExitCode
        cmd
        (optsToCLI opts)
        (show input)

    pure $ case code of
      ExitFailure i -> Left $ MkSystemError i cmd err
      _             -> Right out


optsToCLI :: [CLIOpt] -> CLIOptsInput
optsToCLI = concatMap _optToCLI
  where

  _optToCLI :: CLIOpt -> CLIOptsInput
  _optToCLI MkEmptyOpts         = []
  _optToCLI (MkOptAtomic o)     = [o]
  _optToCLI (MkOptTuple (o, v)) = [o, v]


spawnProcP2Prc :: CLICmd -> [CLIOpt] -> IOEitherError ProcessHandle
spawnProcP2Prc cmd opts =
  do
    let prc = proc cmd $ optsToCLI opts

    creationResult <- createProcess prc

    let (_, _, _, ph) = creationResult

    case creationResult of
      (_, _, Just _, _) -> do

        terminateProcess ph

        pure $ Left $ MkErrorSpawningProcess cmd

      _-> pure $ Right ph


eitherErrorDecode :: Either String a -> Either Error a
eitherErrorDecode esa =
  case esa of
    (Left s)  -> Left $ assignError s
    (Right v) -> Right v


getP2PrcCmd :: IOEitherError String
getP2PrcCmd = do

  -- assumes the program is ran inside the haskell module in p2prc's repo
  -- assumes that last path segment is "haskell" and that p2prc binary's name is "p2p-rendering-computation"

  let trimString = T.unpack . T.strip . T.pack

  eitherErrPwd <- eitherExecProcess "pwd" [MkEmptyOpts] MkEmptyStdInput

  case eitherErrPwd of

    (Right pwdOut) ->
      eitherExecProcess
        "sed"
        [ MkOptAtomic "s/haskell/p2p-rendering-computation/" ]
        $ MkStdInputVal
          $ trimString pwdOut

    err -> pure err
