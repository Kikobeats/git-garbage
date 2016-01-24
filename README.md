# Git Garbage

<p align="center">
  <br>
  <img src="https://i.imgur.com/Mh13XWB.gif" alt="git-garbage">
  <br>
</p>

![Last version](https://img.shields.io/github/tag/Kikobeats/git-garbage.svg?style=flat-square)
[![Build Status](http://img.shields.io/travis/Kikobeats/git-garbage/master.svg?style=flat-square)](https://travis-ci.org/Kikobeats/git-garbage)
[![Dependency status](http://img.shields.io/david/Kikobeats/git-garbage.svg?style=flat-square)](https://david-dm.org/Kikobeats/git-garbage)
[![Dev Dependencies Status](http://img.shields.io/david/dev/Kikobeats/git-garbage.svg?style=flat-square)](https://david-dm.org/Kikobeats/git-garbage#info=devDependencies)
[![NPM Status](http://img.shields.io/npm/dm/git-garbage.svg?style=flat-square)](https://www.npmjs.org/package/git-garbage)
[![Donate](https://img.shields.io/badge/donate-paypal-blue.svg?style=flat-square)](https://paypal.me/Kikobeats)

**NOTE:** more badges availables in [shields.io](http://shields.io/)

> Delete local git branches after deleting them on the remote repository.

## Install

```bash
npm install git-garbage --save
```

## Usage

```js
var gitGarbage = require('git-garbage');

gitGarbage('do something');
//=> return something
```

## API

### gitGarbage(input, [options])

#### input

*Required*
Type: `string`

Lorem ipsum.

#### options

##### foo

Type: `boolean`
Default: `false`

Lorem ipsum.

## License

MIT © [Kiko Beats](http://kikobeats.com)
