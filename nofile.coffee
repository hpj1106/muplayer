nobone = require 'nobone'
{
    kit,
    kit: { path, spawn, Promise }
} = nobone

kit.require 'colors'

module.exports = (task, option) ->

    option '-p, --port <8077>', 'Which port to listen to. Example: cake -p 8077 server', 8077
    option '-q, --quite', 'Running lint script at quite mode results in only printing errors. Example: cake -q coffeelint'
    option '-r, --rebuild', 'Wheather to rebuild src and doc files before run dev server?'
    option '-c, --cli', 'Wheather to run test cases in CLI?'

    task 'setup', 'Setup project.', ->
        setup = require './kit/setup'
        setup()

    task 'build', 'Build all source code.', build = ->
        builder = require './kit/builder'
        builder()

    task 'doc', 'Build doc.', buildDoc = ->
        kit.remove('doc', {
            isFollowLink: false
        }).then ->
            Promise.all([
                kit.spawn('compass', [
                    'compile'
                    '--sass-dir', 'src/css'
                    '--css-dir', 'doc/css'
                    '--no-line-comments'
                ])
                kit.spawn('doxx', [
                    '-d'
                    '-R', 'README.md'
                    '-t', 'MuPlayer 『百度音乐播放内核』'
                    '-s', 'dist'
                    '-T', 'doc_temp'
                    '--template', 'src/doc/base.jade'
                ])
            ])
        .then ->
            copy_to = (from, to) ->
                kit.copy 'doc_temp/' + from, 'doc/' + to

            Promise.all([
                copy_to 'player.js.html', 'api.html'
                copy_to 'index.html', 'index.html'
            ])
        .then ->
            kit.remove 'doc_temp'
        .then ->
            symlink_to = (from, to, type = 'dir') ->
                kit.symlink '../' + from, 'doc/' + to, type

            Promise.all [
                symlink_to 'dist', 'dist'
                symlink_to 'bower_components', 'bower_components'
                symlink_to 'src/doc/img', 'img'
                symlink_to 'src/doc/mp3', 'mp3'
                symlink_to 'src/doc/js', 'js'
                symlink_to 'src/img/favicon.ico', 'favicon.ico', 'file'
                kit.glob 'src/doc/*.html'
                .then (paths) ->
                    for p in paths
                        to = 'doc/' + kit.path.basename p
                        kit.log '>> Link: '.cyan + p + ' -> '.cyan + to
                        kit.symlink '../' + p, to
            ]
        .then ->
            kit.log '>> Build doc done.'.yellow

    task 'server', 'Run dev server.', (opts) ->
        { service, renderer } = nobone()

        run = ->
            service.use '/', renderer.static('doc')
            service.listen opts.port, ->
                kit.log '>> Server start at port: '.cyan + opts.port

        if opts.rebuild
            build(opts)
            .then ->
                buildDoc opts
            .then ->
                run()
        else
            run()

    task 'test', 'Run test runner.', (opts) ->
        if opts.cli
            build(opts)
            .then ->
                spawn 'karma', ['start', 'karma.conf.js'].concat([
                    '--single-run',
                    '--no-auto-watch',
                    # Travis supports running a real browser (Firefox) with a virtual screen.
                    '--browsers', 'Firefox'
                ])
        else
            spawn 'karma', ['start', 'karma.conf.js']

    task 'coffeelint', 'Lint all coffee files.', (opts) ->
        lint = (path) ->
            args = ['-f', 'coffeelint.json', path]
            if opts.quite
                args.unshift('-q')
            spawn 'coffeelint', args

        kit.glob [
            '**/*.coffee',
            '!lib/**/*.coffee',
            '!node_modules/**/*.coffee',
            '!bower_components/**/*.coffee'
            '!doc/bower_components/**/*.coffee'
        ]
        .then (file_list) ->
            Promise.map file_list, lint
