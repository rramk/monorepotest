'use strict'

/**
 * @description echo function
 * @param {array} variable args
 * @return {void}
 */
function echo(...args) {
  console.log(`Hello ${args}`);
}

module.exports = {
  echo
};
