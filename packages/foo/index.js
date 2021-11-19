'use strict'

/**
 * @description echo function
 * @param {array} variable args
 * @param {array} variable args
 * @return {void} return nothing
 */
function echo(...args) {
  console.log(`Hello ${args}`);
}

module.exports = {
  echo
};
