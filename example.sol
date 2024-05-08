// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Программы стейкинга будут развертываться клонами
// Например будет 2 программы стейкинга для двух разных пулов на Raydium
// Желательно сделать добавление новых не через развертывание вручную, а отправкой одной транзакции
// Желательно что бы это мог делать только текущий овнер, а не все подряд
contract StakingProgramm is Ownable {
    // Токен который временно блокируется на контракте
    address public immutable stakedToken;

    // Предустановленные разрешенные периоды стейкинга
    mapping(uint256 lockPeriond => bool exists) public lockPeriods;

    // Модель одного стейкинга
    struct Staking {
        uint256 stakingId; // Идентификатор
        address user; // Владелец токенов
        uint256 amount; // Количество заблокированных токенов
        uint256 lockPeriod; // Период блокировки
        uint256 initialTimestamp; // Начало стейкинга
        bool isUnstaked; // Вывел ли уже пользователь свои токены
    }

    // Потребуется собирать оффчейн сырые данные
    // Для последующего их парсинга в поинты/уровни и тп системы рейтинга
    // Парсинг весь оффчейн. От смарт контрактов нам нужно
    // что бы была возможность спарсить эти данные за разумное время
    event Stake(Staking staking);

    // Просто счетчик ID для стейкинга
    uint256 public stakingIdCounter;

    // Сдесь мы сохраняем сразу все данные ончейн, можно оптимизировать
    mapping(uint256 stakingId => Staking staking) public stakingsById;

    // Список стейкингов каждого пользователя
    // Требуется что бы можно было спарсить всю информацию по пользователю
    mapping(address user => uint256[] stakingIds) public userStakingIds;

    // Вкл/Выкл функции stake
    // Нужна если компания захочет приостановить прием [stakedToken]
    bool public isPaused;

    // При инициализации устанавливается
    // Токен принимаемый в стейкинг
    // Список периодов, в месяцах, например [1,3,6]
    constructor(address initialStakedToken, uint256[] memory initialLockPeriods) {
        stakedToken = initialStakedToken;
        require(initialLockPeriods.length > 0, "empty lock periods!");
        for (uint256 i; i < initialLockPeriods.length; ++i) {
            lockPeriods[initialLockPeriods[i]] = true;
        }
    }

    // Установка паузы овнером
    function setPause(bool value) external onlyOwner {
        isPaused = value;
    }

    // Пользовательская функция
    // Переводит его токены, на адрес стейкинга
    // Генерирует событие для будущего парсинга
    // Так же сохраняем ончейн информацию которая позволит вывести токены(unstake)
    function stake(uint256 amount, uint256 lockPeriod) public {
        require(isPaused == false, "paused!");
        require(lockPeriods[lockPeriod], "lockPeriod not exists!");
        uint256 stakingId = ++stakingIdCounter;

        IERC20(stakedToken).transferFrom(msg.sender, address(this), amount);

        stakingsById[stakingId] = Staking(
            stakingId,
            msg.sender,
            amount,
            lockPeriod,
            block.timestamp,
            false
        );

        emit Stake(stakingsById[stakingId]);
    }

    // Пользовательская функция
    // Позволяет вывести заблокированные токены,
    // Если соблюдены условия:
    // * Юзер тот же что внес токены
    // * Истек период блокировки
    // * Юзер ранее не выводил этот стейкинг (защита от двойного списания)
    function unstake(uint256 stakingId) public {
        Staking storage staking = stakingsById[stakingId];
        require(staking.user == msg.sender, "only staking owner!");
        uint256 expired = staking.initialTimestamp + 30 days * staking.lockPeriod;
        require(block.timestamp > expired, "not ready!");
        require(staking.isUnstaked == false, "already unstaked!");

        staking.isUnstaked = true;
        IERC20(stakedToken).transfer(msg.sender, staking.amount);
    }
}
